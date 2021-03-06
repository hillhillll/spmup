function spmup_despike_reviewlog(varargin)

% SPM U+ utility to review the log file generated by 
% spmup_despike - it will generate a figure that show
% which voxels were despiked ; the figure is pause at
% each volume, simply stroke a key to move forward

if nargin == 0
    [f,p]=uigetfile('spmup_despike_log.mat','Select a despike log');
    cd(p); load(f)
else
    load(varargin{1});    
end

figure('Name','QA'); colormap('hot');
for z=1:size(spmup_despike_log.RMS,3)
    if numel(spmup_despike_log.window) == 1
        imagesc(flipud(spmup_despike_log.RMS(:,:,z)')); axis square;
        title(['RMS Slice ' num2str(z)]);
    else
        subplot(1,2,1);
        imagesc(flipud(spmup_despike_log.window(:,:,z)')); 
        title('Smoothing window'); axis square;
        subplot(1,2,2);
        imagesc(flipud(spmup_despike_log.RMS(:,:,z)')); axis square;
        title(['RMS Slice ' num2str(z)]);
    end
    pause
end

