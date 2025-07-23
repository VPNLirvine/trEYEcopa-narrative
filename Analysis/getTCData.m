function data = getTCData(metricName, varargin)

% data = getTCData(metricName, [taskFlag], [subList])
% Returns a table of data for all subjects with eyetracking, trial num, etc
% Input 1: metric name, as used in selectMetric. e.g. 'tot', 'blinkrate'
% Input 2: task type. Options are 'nar' for narrative or 'tri' for all 100
% Input 3: list of subjects

addpath('..'); % Allow specifyPaths to work
pths = specifyPaths('..');

if nargin == 1 % Default to the original method
    taskFlag = 'data';
    dataPath = pths.eye_data;
    matPath = pths.eye_mat_data;
end

if nargin > 1  % specify relevant paths based on input
    taskFlag = varargin{1};

    if contains(taskFlag, 'pilot')
        dataPath = pths.eye_pilot;
        matPath = pths.eye_mat_pilot;
    else
        dataPath = pths.eye_data;
        matPath = pths.eye_mat_data;
    end
end


%get the list of available edf files to be loaded for further analysis
fileList = dir(dataPath);

if nargin <3  % use all available data
    fnames = {fileList.name};
    subset = cellfun(@(x)endsWith(lower(x), '.edf'), fnames, 'UniformOutput', false);     % String-insensitive compare, in case file extension is uppercase
    subset = cell2mat(subset);
    edfList = fileList(subset);

else  % use a subset of data
    subIDs = arrayfun(@(x) sprintf('TC_%02.f', x), subList, 'UniformOutput', false); % subset edfList to just the subjects specified in the 3rd input
    subset = contains({edfList.name}, varargin{3});
    edfList = edfList(subset);
end
numSubs = length(edfList); % Count the number of subjects to process


% Get some stimulus parameters that are relevant for synchronization -
% Emily doesn't understand what this means
params = importdata('TCstimParams.mat', 'stimParams');


% Initialize an empty dataframe - Requires specifying the data type ahead of time
useCell = any(strcmp(metricName, {'heatmap','gaze', 'track', 'devvec'}));
dheader = {'Subject', 'Eyetrack', 'Response', 'RT', 'Flipped'};
if useCell
    % Let the Eyetrack field take a cell with a 2D matrix
    dtypes = {'string', 'cell', 'double', 'double', 'logical'};
else
    dtypes = {'string', 'double', 'double', 'double', 'logical'};
end
data = table('Size', [0 length(dheader)],'VariableNames', dheader, 'VariableTypes', dtypes);


% Suppress a warning about the way I fill the table
warning('off', 'MATLAB:table:RowsAddedExistingVars');


% Put data for all subjects into one big dataframe
fprintf(1, 'Importing data for %i subjects.\n\n', numSubs);
for subject = 1:numSubs

    % get subject ID
    [junk, subID, ext] = fileparts(edfList(subject).name);

    % check to see if .mat processed eye position file exists
    matfName = strcat(subID, '.mat');
    if exist(fullfile(matPath, matfName))
        
        load(fullfile(matPath, matfName), 'Trials')
        % Trials = importdata(fp);
        % if isfield(Trials, 'FILENAME')    % Emily doesn't understand this
        %     % Convert to look like edfImport output
        %     Trials = edfTranslate(Trials);
        % end
        edf = edfExtractInterestingEvents(Trials);


    else  %if mat doesn't exist, do the tranditional edf conversion

        % Get number of trials from behavioral file instead of EDF.
        % If a subject terminated early, it probably happened during video.
        % The EDF will thus have some data from the stopped trial,
        % while the behavioral file will have skipped the output stage.
    
    
        % Get eyetracking data
        fprintf(1, '%s: ', subID);
        edf = osfImport(fullfile(dataPath, [subID '.edf']));
    end

    % set up to analyze the trials one by one
    behav = getBehData(subID, taskFlag);
    numTrials = height(behav);
    eyetrack = []; % init per sub
    badList = [];

    % Give feedback on progress
    fprintf(1, 'Processing trial 000')
    
        
    for t = 1:numTrials

        fprintf(1, '\b\b\b%03.f', t);
        if isempty(edf(t).Saccades) || behav.Response(t) == -1
            % Either eyetracking data is missing, or no response
            % Don't attempt to extract data that isn't there
            % Remember to drop this trial from the behavioral data
            badList = [badList, t];

            %added to handle when last trial is dumped for whatever
            %reason. Note this cannot handle eyetrack being a cell (see
            %example below)
            eyetrack(t) = 0;


        else % keep the data from the good trials

            opts.flip = logical(behav.Flipped(t));
            % Subset the big stim table to just this trial's data
            stimName = getStimName(edf(t));
            [~,stimName,e] = fileparts(stimName); % strip any path
            if opts.flip
                stimName = stimName(3:end); % strip the 'f_' part
            end
            stimName = strcat(stimName, e);
            opts.params = params(strcmp(params.StimName, stimName),:);

            if useCell
                eyetrack{t} = selectMetric(edf(t), metricName, opts);
                % Note above is cell, not double like below
            else
                eyetrack(t) = selectMetric(edf(t), metricName, opts);
            end
        end
    end
        

    fprintf(1, '\n')
    % Drop trials on the bad list
    behav(badList, :) = [];
    numTrials = height(behav);
    eyetrack(badList) = [];


    % Now Trials is a huge struct of eyetracking data,
    % And behav is a big table of response data.
    % Extract the relevant bits and slice into the dataframe.
    newRange = size(data, 1)+1:size(data, 1)+numTrials;
    data.Subject(newRange) = subID;
    data.Eyetrack(newRange) = eyetrack;
    data.Response(newRange) = behav.Response;
    data.RT(newRange) = behav.RT;
    data.Flipped(newRange) = behav.Flipped;
    data.StimName(newRange) = behav.StimName;


    % end
end % for subject, extracting data
warning('on', 'MATLAB:table:RowsAddedExistingVars');
