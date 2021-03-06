function new_files = spmup_realign_qa(P,varargin)

% implement different quality control 'tools' for
% fMRI realigned data using SPM
%
% FORMAT realign_qa ( = do it all)
%        realign_qa(P,flags)
%
% INPUT P indicate the timeseries to load
%       options are
%       'Motion Parameters': 'on' (default) or 'off'
%              --> plots motion parameters and 1st derivatives
%       'Framewise displacement': 'on' (default) or 'off'
%              --> plots displacement (FD and RMS)                   
%              --> generates/appends new design.txt file with displacement outliers
%       'Voltera': 'off' (fefault) or 'on'
%              --> clompute the motion parameter expansion
%              --> generates/appends new design.txt file with displacement outliers
%       'Globals': 'on' (default) or 'off'
%              --> computes and plot globals (see spm_globals)
%              --> generates/appends new design.txt file with global outliers
%       'Movie': 'on' (default) or 'off'
%       'Coordinate': a coordinate, like [46 64 37];
%              --> generates three movies along the x, y, z planes defined based on the coordinate
%              --> if empty, takes the middle of the volume
%       'Average': where to get the mean image
%       'Figure': : 'on', 'save' (default - save on drive but not visible) or 'off'
%
% Cyril Pernet 
% --------------------------------------------------------------------------
% Copyright (C) spmup team 2019

%% validate inputs
spm('Defaults','fmri')
current = pwd;
 
% check P
if nargin == 0
    [P,sts] = spm_select(Inf,'image' ,'Select your fMRI time series',{},pwd,'.*',Inf);
    if sts == 0
        return
    end
    V = spm_vol(P);
    % bypass orientation check allowing to look at raw data
    N = numel(V);
    Y = zeros([V(1).dim(1:3),N]);
    for i=1:N
        for p=1:V(1).dim(3)
            Y(:,:,p,i) = spm_slice_vol(V(i),spm_matrix([0 0 p]),V(i).dim(1:2),0);
        end
    end
else
    if ischar(P)
        V = spm_vol(P);
        N = numel(V);
        Y = zeros([V(1).dim(1:3),N]);
        for i=1:N
            for p=1:V(1).dim(3)
                Y(:,:,p,i) = spm_slice_vol(V(i),spm_matrix([0 0 p]),V(i).dim(1:2),0);
            end
        end
    elseif iscell(P)
        for v=size(P,1):-1:1
            V(v) =spm_vol(P{v});
        end
        
        for i=numel(V):-1:1
            for p=V(1).dim(3):-1:1
                Y(:,:,p,i) = spm_slice_vol(V(i),spm_matrix([0 0 p]),V(i).dim(1:2),0);
            end
        end
    else
        if numel(size(P)) == 4 % this is already data in
            Y = P; 
        else
            error('input data are not char nor 4D data matrix, please check inputs')
        end
    end
end

% check options
MotionParameters      = 'on';
FramewiseDisplacement = 'on';
Radius                = 50;
Voltera               = 'off';
Globals               = 'on'; 
Movie                 = 'on';
Coordinates           = [];
fig                   = 'save';

if nargin >1
   for v=1:(nargin-1)
      if strcmpi(varargin{v},'Motion Parameters')
           MotionParameters = varargin{v+1};
      elseif strcmpi(varargin{v},'Radius')
           Radius = varargin{v+1};
      elseif strcmpi(varargin{v},'Framewise Displacement')
           FramewiseDisplacement = varargin{v+1};
      elseif strcmpi(varargin{v},'Voltera')
           Voltera = varargin{v+1};
      elseif strcmpi(varargin{v},'Globals')
           Globals = varargin{v+1};
      elseif strcmpi(varargin{v},'Movie')
           Movie = varargin{v+1};
      elseif strcmpi(varargin{v},'Coordinate')
           Coordinates = varargin{v+1};
      elseif strcmpi(varargin{v},'Figure')
           fig = varargin{v+1};
      end
   end
end

% if movie we need AC
if strcmp(Movie,'on')
    if isempty(Coordinates)
        Coordinates = V(1).dim/2; % default
%         Coordinate = input('Coordinate to centre the movie on is missing [x y z]:','s');
%         if ~contains(Coordinate,'[') && ~contains(Coordinate,']')
%             Coordinate = ['[' Coordinate ']'];
%         end
%         Coordinate = eval(Coordinate);
    end
end

findex = 1; % index for the new_files variables

%% look at motion parameters
[filepath,filename]=fileparts(V(1).fname);
if strcmpi(MotionParameters,'on')
    disp('getting displacement ... ')
    motion_file = dir(fullfile(filepath,['rp*' filename(round(length(filename)/2):end) '.txt'])); 
    if size(motion_file,1) > 1
       error('more than one rp*.txt file was found that partially matches the time series name') 
    end
    [FD,RMS] = spmup_FD(fullfile(motion_file.folder,motion_file.name),...
        'Radius',Radius,'Figure',fig);
end

%% look at globals

if strcmpi(Globals,'on')
    disp('computing globals for outliers ... ')
    glo = zeros(length(V),1);
    for s=1:length(V)
        glo(s) = spm_global(V(s));
    end
    glo = spm_detrend(glo,1); % since in spm the data are detrended
    g_outliers = spmup_comp_robust_outliers(glo);
        
    % figure
    figure('Name','Globals outlier detection','Visible','On');
    if strcmpi(fig,'on')
        set(gcf,'Color','w','InvertHardCopy','off', 'units','normalized','outerposition',[0 0 1 1])
    else
        set(gcf,'Color','w','InvertHardCopy','off', 'units','normalized','outerposition',[0 0 1 1],'visible','off')
    end
    plot(glo,'LineWidth',3); title('Global intensity');
    hold on; tmp = g_outliers.*glo; tmp(tmp==0)=NaN; plot(tmp,'or','LineWidth',3);
    grid on; axis tight;  xlabel('scans'); ylabel('mean intensity')
    if strcmpi(fig,'save')
        if exist(fullfile(filepath,'spm.ps'),'file')
            print (gcf,'-dpsc2', '-bestfit', '-append', fullfile(filepath,'spm.ps'));
        else
            print (gcf,'-dpsc2', '-bestfit', '-append', fullfile(filepath,'spmup_QC.ps'));
        end
        close(gcf)
        cd(current)
    end
end

%% make the design.txt file

data = [];
if strcmpi(FramewiseDisplacement,'on')
    data = [data FD RMS];
end

if strcmpi(Globals,'on')
    data = [data glo];
end

if isempty(data) && strcmpi(Voltera,'off')
    disp('no design computed, no extra regressors selected')
else
    spmup_censoring(fullfile(motion_file.folder,motion_file.name),...
        data,'Voltera',Voltera);
    % remane using P
    movefile(fullfile(motion_file.folder,[motion_file.name(4:end-4) '_design.txt']),...
        fullfile(motion_file.folder,[filename '_design.txt']))
    new_files{findex} = fullfile(motion_file.folder,[filename '_design.txt']);
    findex = findex +1;
end


%% make movies
if strcmpi(Movie, 'on')
    new_files{findex} = spmup_movie(Y,'coordinates',Coordinates,...
        'filename',fullfile(filepath,filename),'showfig','off');
end
cd(current)
disp('realign QA done');

