%  * **********************************************************************
%  *
%  * Copyright (c) 2014 Regents of the University of California. All rights reserved.
%  *
%  * Redistribution and use in source and binary forms, with or without
%  * modification, are permitted provided that the following conditions
%  * are met:
%  *
%  * 1. Redistributions of source code must retain the above copyright
%  *    notice, this list of conditions and the following disclaimer.
%  *
%  * 2. Redistributions in binary form must reproduce the above copyright
%  *    notice, this list of conditions and the following disclaimer in the
%  *    documentation and/or other materials provided with the distribution.
%  *
%  * 3. The names of its contributors may not be used to endorse or promote
%  *    products derived from this software without specific prior written
%  *    permission.
%  *
%  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%  * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%  * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
%  * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
%  * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
%  * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
%  * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%  * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%  * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%  * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%  * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%  *
%  * **********************************************************************

%
% spikeWave - Calculates a path using a spiking neuron wave front
%   algorithm. The cost of traversal is reflected in the axonal delays
%   between neurons.
%
% @param map - grid map. values in map reflect cost of traversal.
% @param startX - x coordinate of starting location.
% @param startY - y coordinate of starting location.
% @param endX - x coordinate of goal location.
% @param endY - y coordinate of goal location.
% @param dispWave - displays spike wave and path if set to true.
% @return path - path generated by spike wave front.
function path = spikeWave (map, startX, startY, endX, endY, dispWave)

global GOAL;
GOAL = [endX endY];
global START;
START = [startX startY];

Ne1 = size(map,1);
Ne2 = size(map,2);
SPIKE = 1;
REFRACTORY = -5;
W_INIT = 5;
LEARNING_RATE = 1.0;

% Each neuron connects to its 8 neighbors
wgt = zeros(Ne1,Ne2,Ne1,Ne2);
for i = 1:size(wgt,1)
    for j = 1:size(wgt,2)
        for m = -1:1
            for n = -1:1
%                 if i+m > 0 && i+m <= size(wgt,1) && j+n > 0 && j+n <= size(wgt,2) && (m ~= 0 || n ~= 0)
                if (m == 0 || n == 0) && m ~= n && i+m > 0 && i+m <= size(wgt,1) && j+n > 0 && j+n <= size(wgt,2)
                    wgt(i,j,i+m,j+n) = W_INIT;
                end
            end
        end
    end
end

delayBuffer = zeros(Ne1,Ne2,Ne1,Ne2);
v=zeros(Ne1,Ne2);  % Initial values of v voltage
u=zeros(Ne1,Ne2);  % Initial values of u recovery

% the spike wave is initiated from the starting location
v(startX,startY) = SPIKE;

foundGoal = false;
timeSteps = 0;
aer = [];

while ~foundGoal
    timeSteps = timeSteps + 1;
    [fExcX,fExcY]=find(v >= SPIKE); % indices of spikes
    aer = [aer; [timeSteps*ones(size(fExcX,1),1), fExcX, fExcY]]; % keep spike information in an addressable event representation (spikeID and timeStep)
    
    % Neurons that spike send their spike to their post-synaptic targets.
    % The weights are updated and the spike goes in a delay buffer to
    % targets. The neuron's recovery variable is set to its refractory value.
    if ~isempty(fExcX)
        for i = 1:size(fExcX,1)
            u(fExcX(i),fExcY(i)) = REFRACTORY;
            wgt(fExcX(i),fExcY(i),:,:) = delayRule(wgt(fExcX(i),fExcY(i),:,:),map(fExcX(i),fExcY(i)), LEARNING_RATE);
            delayBuffer(fExcX(i),fExcY(i),:,:) = round(wgt(fExcX(i),fExcY(i),:,:));
            if fExcX(i) == endX && fExcY(i) == endY
                foundGoal = true;   % neuron at goal location spiked.
            end
        end
    end
    
    % if the spike wave is still propagating, get the synaptic input for
    % all neurons. Synaptic input is based on recovery variable, and spikes
    % that are arriving to the neuron at this time step.
    if ~foundGoal
        Iexc = u;
        for i=1:size(v,1)
            for j = 1:size(v,2)
                [fExcX,fExcY]=find(delayBuffer(:,:,i,j) == 1);
                if ~isempty(fExcX)
                    for k = 1:size(fExcX,1)
                        Iexc(i,j) = Iexc(i,j) + (wgt(fExcX(k),fExcY(k),i,j) > 0);
                    end
                end
            end
        end
        % Update membrane potential (v) and recovery variable (u)
        v = v + Iexc;
        u = min(u + 1, 0);
    end
    
%     if dispWave
%         inx = find(v >= SPIKE);
%         dispMap = map;
%         dispMap(inx) = 20;
%         imagesc(dispMap);
%         axis square;
%         axis off;
%         title(['S(', num2str(startX), ',', num2str(startY), ') E(', num2str(endX), ',', num2str(endY), ')'])
%         drawnow
%     end
    
    delayBuffer = max(0, delayBuffer - 1);  % Update the delays of the scheduled spikes.
    
end

path = getPath(aer, map, [startX,startY], [endX,endY]); % Get the path from the AER table.

if dispWave
    pathLen = size(path,2);
    map(path(1).x,path(1).y) = 75;
    for i = 2:pathLen
        map(path(i).x,path(i).y) = 20;
    end
    map(path(end).x,path(end).y) = 50;
    imagesc(map);
    axis square;
    axis off;
    title(['Survey S(', num2str(startX), ',', num2str(startY), ') E(', num2str(endX), ',', num2str(endY), ')'])
end

end


% delayRule - Calculates a delta function for the weights. The weights hold
%   the axonal delay between neurons.
%
% @param wBefore - weight value before applying learning rule.
% @param value - value from the map.
% @param learnRate - learning rate.
% @return - weight value after applying learning rule.
function wAfter = delayRule(wBefore, value, learnRate)

valMat = learnRate * (value - wBefore);
wAfter = wBefore + (wBefore > 0) .* valMat;

end

% getPath - Generates the path based on the AER spike table. The spike
%   table is ordered from earliest spike to latest. The algorithm starts at
%   the end of the table and finds the most recent spike from a neighbor.
%   This generates a near shortest path from start to end.
% 
% @param spks - AER  table containing the spike time and ID of each neuron.
% @param map - map of the environment.
% @param s - start location.
% @param e - end (goal) location.
% @return - path from start to end.
function [ path ] = getPath( spks, map, s, e )

global START;

pinx = 1;
path(pinx).x = e(1);
path(pinx).y = e(2);

while norm([path(pinx).x,path(pinx).y]-[s(1),s(2)]) > 1.0
    pinx = 1;
    path(pinx).x = e(1);
    path(pinx).y = e(2);
    
    % work from most recent to oldest in the spike table
    for i = spks(size(spks,1),1)-1:-1:1
        inx = find(spks(:,1) == i);
        found = false;
        k = 0;
        
        % find the last spike from a neighboring neuron.
        for j = 1:size(inx,1)
            if norm ([path(pinx).x,path(pinx).y] - [spks(inx(j),2),spks(inx(j),3)]) < 1.5
                k = k + 1;
                lst(k,:) = [spks(inx(j),2),spks(inx(j),3)];
                found = true;
            end
        end
        
        % if there is more then one spike, find the one with the lowest
        % cost and closest to starting location.
        if found
            cost = flintmax;
            for m = 1:k
                if map(lst(m,1),lst(m,2)) < cost
                    cost = map(lst(m,1),lst(m,2));
                    minx = m;
                    dist = norm(START - [lst(m,1),lst(m,2)]);
                elseif map(lst(m,1),lst(m,2)) == cost && norm(START - [lst(m,1),lst(m,2)]) < dist
                    minx = m;
                    dist = norm(START - [lst(m,1),lst(m,2)]);
                end
            end
            
            % add the neuron to the path.
            pinx = pinx + 1;
            path(pinx).x = lst(minx,1);
            path(pinx).y = lst(minx,2);
        end
    end
end
end



