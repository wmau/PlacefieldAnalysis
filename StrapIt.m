function [ pval, pvalI ] = StrapIt(Trace,MovMap,Xbin,Ybin,cmperbin,goodepochs,isrunning,toplot,varargin)
% function [ pval ] = StrapIt(Trace,MovMap,Xbin,Ybin,cmperbin,goodepochs,toplot,varargin)
% pval uses entropy, pvalI uses mutual information
% varargin = 'suppress_output',1 supresses output of ExperimentalH, 0 =
% default
%           'use_mut_info': use mutual information metric for pvalues in
%           addition to entropy

suppress_output = 0;
use_mut_info = 0;
for j = 1:length(varargin)
    if strcmpi('suppress_output',varargin{j})
       suppress_output = varargin{j+1};
    end
    if strcmpi('use_mut_info',varargin{j})
       use_mut_info = varargin{j+1};
    end
    
end

if (nargin < 8)
    toplot = 0;
end

NumShuffles = 500;

% count the number of cell activations and their sizes

NumAct = 0;
ActLengths = [];

for i = 1:size(goodepochs,1)
    estart = goodepochs(i,1);
    eend = goodepochs(i,2);
    tempact = NP_FindSupraThresholdEpochs(Trace(estart:eend),0.01,0);
    if(isempty(tempact) ~= 1)
        NumAct = NumAct + size(tempact,1);
        ActLengths = [ActLengths;((tempact(:,2)-tempact(:,1))+1)];
    end
end

% Note that this uses the disk fiter only currently - need to return to
% this in the future
[placemap, ~, placemap_nosmooth] = calcmapdec(Trace, MovMap, Xbin, Ybin, isrunning, cmperbin);
if suppress_output == 0
    ExperimentalH = DaveEntropy(placemap)
    if calc_mut_info == 1
       ExperimentalI = calc_mutual_information(placemap_nosmooth,MovMap)
    end
elseif suppress_output == 1
    ExperimentalH = DaveEntropy(placemap);
    if calc_mut_info == 1
       ExperimentalI = calc_mutual_information(placemap_nosmooth,MovMap);
    end
end
    

runlengths = goodepochs(:,2)-goodepochs(:,1)+1;
runused = zeros(size(runlengths));

parfor i = 1:NumShuffles
    
    shufftrace = zeros(size(Trace));
    for j = 1:NumAct
        % randomly pick a running epoch to assign to
        diditgood = 0;
        while (diditgood == 0)
            randrun = ceil(rand*size(goodepochs,1));
            rs = goodepochs(randrun,1);
            re = goodepochs(randrun,2);
            
            if (runlengths(randrun) > ActLengths(j))
                % this Activation *might* fit 
                maxoffset = runlengths(randrun) - ActLengths(j);
                % pick a place within the run to put the activation
                randoffset = floor(rand*(maxoffset+1));
                temp = shufftrace(rs:re);
                temp(1+randoffset:1+randoffset+ActLengths(j)-1) = temp(1+randoffset:1+randoffset+ActLengths(j)-1)+1;
                if (max(temp) < 2)
                    % this Activation doesn't overlap with another we've
                    % laid down
                    diditgood = 1;
                    shufftrace(rs+randoffset:rs+randoffset+ActLengths(j)-1) = 1;
                end
            end

            
        end
    end
    
    [tempplacemap, ~] = calcmapdec(shufftrace, MovMap, Xbin, Ybin, isrunning, cmperbin);
    ShuffH(i) = DaveEntropy(tempplacemap);
    if calc_mut_info == 1
       ShuffI(i) = calc_mutual_information(tempplacemap,MovMap);
    end
    %figure(999);plot(Trace);hold on;plot(shufftrace,'-r');hold off;pause;
end

pval = length(find(ShuffH > ExperimentalH))./NumShuffles;
if use_mut_info == 1
    pvalI = length(find(ShuffI > ExperimentalI))./NumShuffles;
else
    pvalI = [];

end

end


        




    
    
    
    





