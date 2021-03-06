function batch_align_pos(base_struct, reg_struct, varargin)
% batch_align_pos(base_struct, reg_struct, varargin)
%
% Aligns position data so that every session has the same bounds on the
% occupancy map and we can easily do correlations and other comparisons
% between firing across sessions.  Everything gets scaled to the
% trajectory/occupancy from the base session. IMPORTANT NOTE: running this
% WILL overwrite any previous Pos_align.mat files, so be careful (though
% not too careful since using this function is fairly quick)
%
% INPUTS: 
%   base_struct & reg_struct:
%        mirror MD from MakeMouseSessionList, but must include at least
%       .Animal, .Date, .Session, AND .Room fields (and .Notes if you wish
%       to perform auto-rotation of the arena back to the standard
%       configuration)
%
% OPTIONAL INPUTS (specify as batch_align_pos(...,'manual_rot_overwrite,1,...):
%
%   manual_rot_overwrite: default = 1, will prompt you to
%       perform the rotation CORRECTION (e.g., re-aligning a slightly skewed
%       session) for each session, 0 will use pre-existing rotation
%       data in rotated.mat file in the working directory if it exists
%
%   ratio_use: ratio of the data to use for alignment - if 0.95, then
%       data is scaled so that the middle 95% of it in each session aligns with
%       the middle 95% in other sessions.  default = 0.95.
%
%   auto_rotate_to_std: set to 1 if you want to automatically rotate the
%       data back to the standard orientation if you have rotated the arena
%       as part of a control for distal v local cues.  Set to 0 if you want
%       to leave it alone (default).  IMPORTANT NOTES: 1) for this to work, the rotation of
%       the arena must be in the .Notes field of base_struct and
%       reg_struct. 2) 
%
%   manual_limits: set to 1 to manually draw the limits of the arena you
%       want to scale (default = 0).  Use this if, for example, you want to 
%       only consider the left part of a large arena that is joined to another.  
%       Input is either a single logical value, in which
%       case it applies to all sessions, or you can input a logical array where
%       the 1st entry corresponds to the base session, and the subsequent
%       entries correspond to all the registered sessions (e.g. [0 1 0 1] =
%       manually draw limits for the 1st and 3rd registered sessions but
%       not the base session or 2nd registered session)
%
%       name_append: this will be appended to the Pos_align or
%       Pos_align_std_corr if you specify it
%
%       circ2square_use: logical with 1 indicating to use circle data
%       that has been transformed to square data (in Pos_trans.mat).  Will
%       save all data in Pos_align_trans.mat or
%       Pos_align_std_corr_trans.mat.
%
%   halfwindow: half the temporal smoothing window used - mainly obsolete,
%       but you may need to use if your data is offset for some reason.
%       Default = 0.
%
% OUTPUTS (saved in Pos_align.mat in working directory, or Pos_align_std_corr.mat
%          if you choose to auto-rotate back):
%
%   'x_adj_cm','y_adj_cm': x and y positions converted to centimeters and
%   scaled/aligned to the base session such that all sessions align
%
%   'xmin','xmax','ymin','ymax': min and max position data for ALL sessions
%   that can be sent to CalculatePlacefields such that the occupancy maps,
%   heat maps, etc. are all identical in size
%
%   'speed','FT','FToffset','FToffsetRear': calculated from  
%    
%   'base_struct':
%   'sessions_included':
%
% NOTE: this may not work well for the 2 environment experiment since it
% does not account for any fish-eye distortions of the maze...should be
% good for most comparisons between the same mazes, however

close all;
global MasterDirectory;
MasterDirectory = 'C:\MasterData';

%% Parameters/default values
p = inputParser;
p.addRequired('base_struct',@(x) isstruct(x));
p.addRequired('reg_struct',@(x) isstruct(x)); 
p.addParameter('manual_rot_overwrite',true,@(x) islogical(x));
p.addParameter('ratio_use',0.95,@(x) isscalar(x)); 
p.addParameter('auto_rotate_to_std',false,@(x) islogical(x)); 
p.addParameter('manual_limits',zeros(1,length(reg_struct)+1),@(x) islogical(x));
p.addParameter('name_append','',@(x) ischar(x)); 
p.addParameter('circ2square_use',false,@(x) islogical(x)); 
p.addParameter('TenaspisVer',4,@(x) isscalar(x) & x>2); 

p.parse(base_struct,reg_struct,varargin{:});
manual_rot_overwrite = p.Results.manual_rot_overwrite;
ratio_use = p.Results.ratio_use;
auto_rotate_to_std = p.Results.auto_rotate_to_std;
manual_limits = p.Results.manual_limits;
name_append = p.Results.name_append;
circ2square_use = p.Results.circ2square_use;
TenaspisVer = p.Results.TenaspisVer;
xmin = 10; ymin = 20;

%% 1: Load all sessions, and align to imaging data

% Dump everything into one structure for future ease
sesh = [base_struct, reg_struct];

for j = 1: length(sesh)
    cd(sesh(j).Location);
    Pix2Cm = sesh(j).Pix2CM; 
    disp(['Using ', num2str(Pix2Cm), ' as Pix2CM for ', sesh(j).Date, ' session ', num2str(sesh(j).Session)]);
    
    if TenaspisVer==4
        disp('Loading results from Tenaspis v4.');
        HalfWindow = 0;
        load(fullfile(pwd,'FinalOutput.mat'),'PSAbool','NeuronTraces');  
        LPtrace = NeuronTraces.LPtrace;
        DFDTtrace = NeuronTraces.DFDTtrace; 
        RawTrace = NeuronTraces.RawTrace;
        clear NeuronTraces;
    elseif TenaspisVer==3
        disp('Loading results from Tenaspis v3.');
        HalfWindow = 0;
        load(fullfile(pwd,'FinalOutput.mat'),'FT');
        load(fullfile(pwd,'FinalTraces.mat'),'trace','difftrace','rawtrace');
        PSAbool = FT;
        LPtrace = trace;
        DFDTtrace = difftrace; 
        RawTrace = rawtrace;
        clear FT trace difftrace rawtrace;
    end
    
    % Align tracking and imaging
    [x,y,speed,PSAbool,FToffset,FToffsetRear,aviFrame,time_interp,nframesinserted] = ...
        AlignImagingToTracking(Pix2Cm,PSAbool,HalfWindow);
    [~,~,~,LPtrace] = AlignImagingToTracking(Pix2Cm,LPtrace,HalfWindow);
    [~,~,~,DFDTtrace] = AlignImagingToTracking(Pix2Cm,DFDTtrace,HalfWindow);
    [~,~,~,RawTrace] = AlignImagingToTracking(Pix2Cm,RawTrace,HalfWindow);
    
%     % Transform circle data if indicated AND if in the square
%     if circ2square_use == 1 && ~isempty(regexpi(sesh(j).Env,'octagon')) 
%        [ x, y ] = circ2square_full(sesh(j),Pix2Cm);
%     end
    
    % Auto-rotate back to standard configuration if indicated
    if auto_rotate_to_std == 1
        rot_corr = get_rot_from_db(sesh(j));
        [x, y] = rotate_arena(x,y,rot_corr);
    end
    
    sesh(j).x = x;
    sesh(j).y = y;
    sesh(j).PSAbool = PSAbool;
    sesh(j).LPtrace = LPtrace;
    sesh(j).DFDTtrace = DFDTtrace;
    sesh(j).RawTrace = RawTrace;
    sesh(j).speed = speed;
    sesh(j).FToffset = FToffset;
    sesh(j).FToffsetRear = FToffsetRear;
    
    % Fix day-to-day mis-alignments in rotation of the maze
    skewed = true;
    while skewed
        [rot_x,rot_y,rot_ang] = rotate_traj(x,y);
        plot(rot_x,rot_y); 
        satisfied = input('Are you satisfied with the rotation? Enter y or n-->','s');
        skewed = ~strcmp(satisfied,'y');
    end
        
    sesh(j).rot_x = rot_x;
    sesh(j).rot_y = rot_y;
    sesh(j).rot_ang = rot_ang;
    sesh(j).aviFrame = aviFrame;
    sesh(j).time_interp = time_interp;
    sesh(j).nframesinserted = nframesinserted;
end


%% 2: Align position data for each session to the base session by using the 95% occupancy limits, save as Pos_align.mat
% Include base session in Pos_align for future reference

% Add in opportunity to manually select data limits to use here... if the
% flag you set for it is 1 - may want to do this by looking at the Notes
% section in MD

for j = 1:length(sesh)
    
    if ~manual_limits(j)
        x_for_limits = sesh(j).rot_x;
        y_for_limits = sesh(j).rot_y;
        sesh(j).ind_keep = true(1,length(sesh(j).rot_x));
    elseif manual_limits(j)
        [x_for_limits, y_for_limits, sesh(j).ind_keep] = draw_manual_limits(...
            sesh(j).rot_x, sesh(j).rot_y);
    end
    
    % Transform circle to square if indicated
    if circ2square_use && ~isempty(regexpi(sesh(j).Env,'octagon')) 
        %Arena Size Parameters
        circle_radius = 14.33;
        square_side = 25.4;
        [x_for_limits, y_for_limits] = circ2square(x_for_limits, ...
            y_for_limits, square_side, circle_radius );
        sesh(j).rot_x = nan(size(sesh(j).rot_x));
        sesh(j).rot_y = nan(size(sesh(j).rot_y));
        sesh(j).rot_x(sesh(j).ind_keep) = x_for_limits; 
        sesh(j).rot_y(sesh(j).ind_keep) = y_for_limits;
    end
    
    % Get ecdfs of all x and y points
    [sesh(j).e_fx, sesh(j).e_x] = ecdf(x_for_limits);
    [sesh(j).e_fy, sesh(j).e_y] = ecdf(y_for_limits);
    % Find limits that correspond to ratio_use (e.g. if ratio_use = 0.95,
    % look for the x value that corresponds to 0.025 and 0.975)
    xbound{j}(1) = sesh(j).e_x(findclosest((1-ratio_use)/2,sesh(j).e_fx));
    xbound{j}(2) = sesh(j).e_x(findclosest(1 - (1-ratio_use)/2,sesh(j).e_fx));
    ybound{j}(1) = sesh(j).e_y(findclosest((1-ratio_use)/2,sesh(j).e_fy));
    ybound{j}(2) = sesh(j).e_y(findclosest(1 - (1-ratio_use)/2,sesh(j).e_fy));
    % Calculate the span and get the ratio to the base span
    span_x(j) = xbound{j}(2) - xbound{j}(1);
    span_y(j) = ybound{j}(2) - ybound{j}(1);
    if j == 1
        span_x_ratio = 1;
        span_y_ratio = 1;
    elseif j > 1
        span_x_ratio = span_x(j)/span_x(1);
        span_y_ratio = span_y(j)/span_y(1);
    end
    
    % Linearly adjust all the coordinates to match - use all position data!
    sesh(j).x_adj = (sesh(j).rot_x - xbound{j}(1))/span_x_ratio + xmin;
    sesh(j).y_adj = (sesh(j).rot_y - ybound{j}(1))/span_y_ratio + ymin; 
end
%% 4: Concatenate ALL position data into one X and one Y vector, and get Xedges and Yedges based on this

x_all = [];
y_all = [];
for j = 1:length(sesh)
    x_all = [x_all sesh(j).x_adj(sesh(j).ind_keep)]; % Only use data within the limits you drew for this!
    y_all = [y_all sesh(j).y_adj(sesh(j).ind_keep)]; % Only use data within the limits you drew for this!
end

%% 5: Get xmin, xmax, ymin, and ymax

xmax = max(x_all);
xmin = min(x_all);
ymax = max(y_all);
ymin = min(y_all);

%% 6: Save Xedges, Yedges in base session for future reference along with all sessions aligned to it.
% Also save adjusted position data for future use...

sessions_included = [base_struct reg_struct];

for j = 1:length(sesh)
    x_adj_cm = sesh(j).x_adj;
    y_adj_cm = sesh(j).y_adj;
    speed = sesh(j).speed;
    PSAbool = sesh(j).PSAbool;
    LPtrace = sesh(j).LPtrace;
    DFDTtrace = sesh(j).DFDTtrace;
    RawTrace = sesh(j).RawTrace;
    FToffset = sesh(j).FToffset;
    FToffsetRear = sesh(j).FToffsetRear;
    aviFrame = sesh(j).aviFrame;
    time_interp = sesh(j).time_interp;
    nframesinserted = sesh(j).nframesinserted;
    if ~auto_rotate_to_std
    save(fullfile(sesh(j).Location,['Pos_align' name_append '.mat']),...
        'x_adj_cm','y_adj_cm','xmin','xmax','ymin','ymax','speed',...
        'PSAbool','LPtrace','DFDTtrace','RawTrace','FToffset',...
        'nframesinserted','time_interp','FToffsetRear','aviFrame',...
        'base_struct','sessions_included','auto_rotate_to_std');
    elseif auto_rotate_to_std
        % finish here - save as a different filename?
        save(fullfile(sesh(j).Location,...
            ['Pos_align_std_corr' name_append '.mat']),'x_adj_cm',...
            'y_adj_cm','xmin','xmax','ymin','ymax','speed','PSAbool',...
            'LPtrace','DFDTtrace','RawTrace','FToffset','nframesinserted',...
            'time_interp','FToffsetRear','aviFrame','base_struct',...
            'sessions_included', 'auto_rotate_to_std');
    end
end

%% 7: Plot everything as a check
figure(100);
for j = 1:length(sesh)
    % Plot on an individual subplot
    subplot_auto(length(sesh) + 1,j+1);
    plot(sesh(j).x_adj,sesh(j).y_adj);
    xlim([xmin xmax]); ylim([ymin ymax])
    title(['Session ' num2str(j)])
    % Plot everything on top of the other
    subplot_auto(length(sesh) + 1, 1);
    hold on
    plot(sesh(j).x_adj, sesh(j).y_adj);
    xlim([xmin xmax]); ylim([ymin ymax])
    hold off
    title('All Sessions')
end

end

