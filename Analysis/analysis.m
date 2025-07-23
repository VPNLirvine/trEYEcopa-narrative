function varargout = analysis(varargin)
% Perform statistical analysis on eyetracking data
% Optional input 1 should be a metric name listed in selectMetric()
close all;

metricName = 'scaledfixation';  % by default, use percent time spent fixating
if nargin > 0
    metricName = varargin{1};
end
 
data = [];
if nargin > 1
    data = varargin{2};
end

% The exact test depends on which stimulus set we're looking at, so force a choice:
choice = menu('Which data do you want to analyze?','TriCOPA NarrPilot', 'TriCOPA Narration');

% TriCOPA Narratives - pilot data
fprintf(1, 'Using metric %s\n\n', metricName);
if isempty(data)
    if choice == 1
        dataSource = 'pilot';
    else
        dataSource = 'data';
    end

    data = getTCData(metricName, dataSource);

    % if strcmp(metricName, 'ISC')
    %     data = doISC(getTCData('heatmap', dataSource));
    % elseif strcmp(metricName, 'coherence')
    %     [~, data] = doGazePath(getTCData('gaze', dataSource));
    % else
    %     data = getTCData(metricName, dataSource);
    % end

    % fprintf(1, 'Mean ISC = %0.2f%%\n', 100 * mean(data.Eyetrack));
    % fprintf(1, 'Median ISC = %0.2f%%\n', 100 * median(data.Eyetrack));

    % 
    % Compress the timecourse down to a single number
    % for i = 1:height(data)
    %     data.Eyetrack{i} = mean(data.Eyetrack{i}(1,:), 'omitnan');
    % end
    % Now that they're not vectors, turn the column into a single mat
    % data.Eyetrack = cell2mat(data.Eyetrack);
end


% Identify subjects based on the gaze data
subList = unique(data.Subject);
numSubs = size(subList, 1);


% get AQ data
try
   aqTable = getAQ_QuestionProFormat(specifyPaths('..'));
   if numSubs ~= height(aqTable)
        fprintf(1, '\nError: There are %i EDF files and %i AQ scores. ', numSubs, numAQ);
   end
catch
    fprintf(1, 'getAQ_QuestionProFormat.m function not yet written\n')
end

% get BVAQ data
try
    bvaqTable = getBVAQ_QuestionProFormat(specifyPaths('..'));
    if numSubs ~= height(bvaqTable)
        fprintf(1, 'Error: There are %i EDF files and %i BVAQ scores. ', numSubs, numAQ);
   end

catch
    fprintf(1, 'getBVAQ_QuestionProFormat.m function not yet written\n')
end


% compute correlation between questionnaire subscores
try
    computeSubscorecorr(AQtable, bvaqTable) %requires 1 input, can take up to 3
catch
    fprintf(1, 'Error: Independence of questionnaire subscores not computed\n')
end



%% ------ I mostly stopped here ----- %%
% Compare the eyetracking data to the behavioral data
fprintf(1, '\nImporting the behavioral files (responses at end of each trial)\n')
for sub = 1:numSubs
    subID = subList(sub, :);
    try
        behav(:, :, sub) = getBehData(subID, dataSource); % get challenge scores
    catch
        fprintf(1, '\nSub %i behavioral file not found or array size mismatch\n', sub)
    end
end

% Get axis labels for later
% [var1, yl, distTxt] = getGraphLabel(metricName);
% [var2, yl2, distTxt2] = getGraphLabel('response');

   
    
% Get the average gaze metric per subject, to correlate with AQ
% (since there's only one AQ score per subject)
eyeCol = zeros([numSubs, 1]); % preallocate as column
for s = 1:numSubs
    subID = subList{s};
    subset = strcmp(subID, data.Subject);
    eyeCol(s) = mean(data.Eyetrack(subset), 'all', 'omitnan');
end


% Calculate correlations and generate some visualizations
% None of these involve AQ, so do them before the upcoming loop
eye2rating = getCorrelations(data, metricName); % gaze vs rating
data = getCorrelation2(data, metricName); % gaze vs motion
data = getCorrelation3(data, metricName); % gaze vs interactivity

% Get the average video rating per subject (not collected for MW)
eyeData = zeros([numSubs, 1]); % preallocate as column
for s = 1:numSubs
    subID = subList{s};
    subset = strcmp(subID, data.Subject);
    eyeData(s) = mean(data.Response(subset), 'all', 'omitnan');
end

% calculate relationship between eye gaze metric (average across trials)
% and trait subscales
computeTraitvsEye(traitTable, eyeData)



% plotItemwise(data, metricName, mwflag);
% 
% % Export data matrix on request
% if nargout > 0
%     % Prepare for regression:
%     % 1. Reset AQ to be Social Skills specifically,
%     % since the other two subscales have a low effect
%     for i = 1:height(aqTable)
%         subID = aqTable.SubID{i};
%         subset = strcmp(data.Subject, subID);
%         data.AQ(subset) = aqTable.SocialSkills(i);
%     end
%     % 2. Convert strings to 'categorical' variables
%     % data.Subject = categorical(data.Subject);
%     % data.StimName = categorical(data.StimName);
%     % if mwflag
%     %     data.Category = categorical(data.Category);
%     % end
%     varargout{1} = data;
% end