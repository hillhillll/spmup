function [FD,RMS,motion] = spmup_FD(realignment_file,varargin)

% simple routine that computes framewise displacement as a sum (FD) and RMS (a.k.a. DVARS)
% Power et al. (2012) doi:10.1016/j.neuroimage.2011.10.018  
% Power et al. (2014) doi:10.1016/j.neuroimage.2013.08.048
% also return the Volterra expansion of motion parameters 
% Friston et al (1996) Magn Reson Med. 1996;35:346:355.
%
% FORMAT: [FD,RMS,motion] = spmup_FD(realignment_file,radius,'figure','on/save/off')
% 
% INPUT: realigment is the realigment parameters file
%        radius is the expected head radius (default 50 mm)
%        figure on: plots parameters, save: save a plot of parameter in
%        directory of motion parameters; off: nothing
%
% OUTPUT: FD framewise displacement
%         RMS the root mean square displacement 
%         motion, the expanded motion parameters
%
% Cyril Pernet - University of Edinburgh
% -----------------------------------------
% Copyright (c) SPM Utility Plus toolbox

%% input
current = pwd;
radius  = 50;
fig     = 'save';
FD      = NaN;
RMS     = NaN;
motion  = NaN;

if nargin == 0
    [filename,filepath,sts] = uigetfile('*.txt','select realignement parameters');
    if sts == 0
        return
    else
        realignment_file = [filepath filesep filename];
    end
elseif nargin == 2
    radius = varargin{1};
elseif nargin == 3
    fig = 'on';
elseif nargin == 4
    fig = varargin{3};
    if ~strcmpi(fig,'on') || ~strcmpi(fig,'off') || ~strcmpi(fig,'save')
        fig = 'save';
    end
end

if isempty(radius)
    radius = 50;
end

%% read
motion            = load(realignment_file); % load data
motion            = motion(:,1:6); % make sure to pick only the initial 6 if another file is used
motion            = spm_detrend(motion,1); % de-mean and detrend
motion(:,[4 5 6]) = motion(:,[4 5 6]).*radius; % angle in radian by average head size = displacement in mm

%% compute
D      = diff(motion,1,1); % 1st order derivative
D      = [zeros(1,6); D];  % set first row to 0
FD     = sum(abs(D),2); % framewise displacement a la Powers
RMS    = sqrt(mean(detrend(D).^2,2)); % root mean square for each column a la Van Dijk
motion = [motion D motion.^2 D.^2];

%% figure
if strcmpi(fig,'on') || strcmpi(fig,'save')
    figure('Name','Motion and displacement')
    set(gcf,'Color','w','InvertHardCopy','off', 'units','normalized','outerposition',[0 0 1 1])
    subplot(2,2,1); plot(motion(:,[1 2 3]),'LineWidth',3); axis tight; box on; grid on; title('translation')
    subplot(2,2,2); plot(motion(:,[4 5 6]),'LineWidth',3); axis tight; box on; grid on; title('rotation')
    subplot(2,2,3); plot(FD,'LineWidth',3); axis tight; box on; grid on; title('framewise displacement')
    subplot(2,2,4); plot(RMS,'LineWidth',3); axis tight; box on; grid on; title('root mean square')
    
    if strcmpi(fig,'save')
        cd(fileparts(realignment_file))
        try
            print (gcf,'-dpsc2', '-bestfit', [pwd filesep 'displacement.ps']);
        catch
            print (gcf,'-dpsc2', [pwd filesep 'displacement.ps']);
        end
        close(gcf)
        cd(current)
    end
end
