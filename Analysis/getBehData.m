function behav = getBehData(subID, taskFlag)

pths = specifyPaths;

if strcmp(taskFlag, 'pilot')
    fPath = pths.beh_pilot;
else
    fPath = pths.beh_data;
end

fList = dir(strcat(fPath, subID, '_task-TriCOPA_', '*.txt'));
if isempty(fList)
    warning('Could not find behavioral data file for subject %s; skipping\n', subID);
    behav = [];
else
    behav = readtable(fList(1).name, 'Delimiter', '\t'); %what are the dimensions of this??
    behav = processBeh(behav); % convert stim folder to a variable
end
