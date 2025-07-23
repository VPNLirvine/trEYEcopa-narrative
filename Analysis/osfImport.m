function [Trials, Preamble] = osfImport(fileName_withPath)
% Import an edf file to matlab using OSF edfImport() and edfExtractInterestingEvents() 
% Input 1 is expected to contain the entire path
% This function analyzes that path to determine if the data is TC, MW, etc.
% If data was saved to .mat (in another folder), will load that instead.

addpath('..'); % to allow specifyPaths to run
pths = specifyPaths('..');


try
    % convert to character, if needed
    if ~ischar(fileName_withPath)
        fileName_withPath = char(fileName_withPath);
    end
    [path, subID, ext] = fileparts(fileName_withPath);

    % %% adding file extension if necessary
    % if (isempty(regexpi(fileName_withPath, '.edf$')))
    %     fileName_withPath= [fileName_withPath '.edf'];
    % end
    

    % set up proper input/output file paths
    addpath(pths.edf);

    if contains(fileName_withPath,['source' filesep 'data'])
        edfPath = pths.eye_data;
        matPath = pths.eye_mat_data;
    elseif contains(fileName_withPath,['source' filesep 'pilot'])
        edfPath = pths.eye_pilot;
        matPath = pths.eye_mat_pilot;
    else
        fprintf(1, 'Error: Not able to identify relevant path definitions for edf files')
    end

    

    % % Check for .mat file, in case bad subject (or just to be lazy)
    % [~,fileName2] = fileparts(fileName_withPath);
    % % fileName2 = [fileName2(1:end-3) 'mat'];
    % fileName2 = [fileName2 '.mat'];
    % fp = fullfile(matLoc, fileName2);

   


    % Perform standard import via mex
    [Trials, Preamble] = edfImport(fileName_withPath, [1 1 1], '');

    % Export to mat file, to save time on future imports
    if ~exist(matPath, 'dir')
        mkdir(matPath)
    end
    save(fullfile(matPath, subID) , 'Trials');
    fprintf(1, 'Data exported to %s\n', matPath);


    Trials = edfExtractInterestingEvents(Trials);

catch ME
    disp(ME.identifier)
    disp(ME.message)
end

end