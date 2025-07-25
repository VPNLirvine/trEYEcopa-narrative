function [output, varargout] = selectMetric(edfDat, metricName, varargin)
% Takes in a single row of an edf file (ie already indexed by trial number)
% e.g. input should be edfFile(trialNum), not edfFile itself
% Given a metric name like 'totfixation', calculate and return that metric
% Options are as follows:
%   'totalfix' - Total fixation time per trial
%   'scaledfixation' - Percentage of video time spent fixating
%   'firstfix' - Duration of the initial fixation - like an RT to the video
%   'duration' - Duration of the video in sec (a QC metric)
%   'meanfix' - Average fixation duration within a trial
%   'medianfix' - Median fixation duration within a trial
%   'maxfixOnset' - Onset time of the longest fixation
%   'minfixOnset' - Onset time of the shortest fixation
%   'meansacdist' - Average distance of all saccades within a trial
%   'heatmap' - a 2D heatmap summarizing the scanpath
%   'gaze' - gives the scanpath as coords over time. Rows are X, Y, and T.
%   'blinkrate' - Number of blinks / duration of video (in Hz)
%   'deviance' - Instantaneous deviation of gaze from a predicted path
%   'similarity' - Correlation b/w predicted and actual scanpath

% Determine how many eyes were used
% values of n: 0 = left, 1 = right.
% Length of n should be the number of eyes tracked.
% If more than one, pick one eye at random and ignore the other
n = unique(edfDat.Saccades.eye);
if length(n) == 2
    i = round(rand());
else
    i = n;
end

% See if the optional screen dimensions were included
if nargin > 3
    % Expecting screen dimensions: [xsize ysize]
    % e.g. a typical HD screen is [1920 1080]
    scDim = varargin{2};
    assert(length(scDim) == 2, '4th input must be a 2-element array of screen dimensions: [xwidth yheight]');
else
    % Use defaults
    scDim = [1920 1200];
end

% See if the data needs to be flipped or not
if nargin > 2 && ~isempty(varargin{1})
    opts = varargin{1};
    flipFlag = opts.flip;
    assert(islogical(flipFlag), 'flipFlag must be logical');
    stimParams = opts.params;
else
    flipFlag = false;
    % hope for the best re stimParams
end

% Account for differences between TRIAL duration and STIMULUS duration
% (the full stream of samples per trial includes drift checking etc)

% Find timepoints bounding stimulus presentation
stimStart = findStimOnset(edfDat);
stimEnd = findStimOffset(edfDat);
recStart = edfDat.Header.rec.time; % time eyetracker starts recording

% The EDF file's 'duration' field is unreliable:
% sometimes it's 0, sometimes it's far less than the event durations,
% so just calculate it from start and end time instead.
duration = stimEnd - stimStart;

% There is a short delay b/w the eyetracker starting and stimulus onset.
% All the "Fixation" onset times are relative to the former, not the latter.
% e.g. a fixation with sttime == 100 began 100ms after recording,
% which may be before the stimulus actually started.
% Filter out any events that begin before this delay has passed.
recOffset = stimStart - recStart; % delay b/w eyetracker and stim, ~140ms

% Look for end times that happen before this interval.
recDur = stimEnd - recStart;


switch metricName
    case 'fixations'
        % Hidden metric that exports a vector of fixations
        % This helps standardize the outlier rejection etc across metrics
        data = edfDat.Fixations.time(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        % data = [selectMetric(edfDat, 'firstfix', varargin) data]; % re-insert first fixation as well??
        data = [data selectMetric(edfDat, 'lastfix', varargin{:})]; % include the cut-off final fixation
        output = fixOutliers(data);
    case 'totalfix'
        data = selectMetric(edfDat, 'fixations', varargin{:});
        output = sum(data);
    case 'gap'
        % This is ultimately meaningless
        % so if it correlates strongly with anything,
        % you've likely got a bug in your pipeline.
        output = recOffset;
    case 'scaledfixation'
        data = selectMetric(edfDat, 'totalfix', varargin{:});
        output = data / duration;
    case 'firstfix'
        data = edfDat.Fixations.entime(edfDat.Fixations.eye == i & edfDat.Fixations.sttime <= recOffset & edfDat.Fixations.entime >= recOffset);
        if isempty(data)
            output = NaN;
        else
            % I selected the END TIME of the fixation, not the duration.
            % The start time could be ANY time b/w recStart and stimStart,
            % But the end time is always relative to recStart.
            % Subtracting recOffset gives you the duration from video on,
            % so that this becomes a sort of reaction time to the video.
            output = data - recOffset;
        end
    case 'lastfix'
        % Please don't analyze this by itself
        data = edfDat.Fixations.sttime(edfDat.Fixations.eye == i & edfDat.Fixations.sttime <= recDur & edfDat.Fixations.entime >= recDur);
        if isempty(data)
            output = [];
        else
            % I selected the START TIME of the fixation, not the duration.
            % The end time could be ANY time after the stim ends,
            % but we need to ignore that part,
            % and just get the portion from its start to the video end.
            % Since Fixations.sttime is relative to recording onset,
            % we need to subtract recOffset as well.
            % The result is the duration of the final fixation,
            % minus any time it lasted after the video ended.
            output = (stimEnd - stimStart) - data(end) - recOffset;
        end
    case 'duration'
        output = getStimDuration(edfDat);
    case 'meanfix'
        data = selectMetric(edfDat, 'fixations', varargin{:});
        output = mean(data);
    case 'medianfix'
        data = selectMetric(edfDat, 'fixations', varargin{:});
        output = median(data);
    case 'maxfixOnset'
        data = edfDat.Fixations.time(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        data = fixOutliers(data);
        [~, position] = max(data);
        output = edfDat.Fixations.sttime(:,position);
    case 'minfixOnset'
        data = edfDat.Fixations.time(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        data = fixOutliers(data);
        [~, position] = min(data);
        output = edfDat.Fixations.sttime(:,position);
    case 'meansacdist'
        data = edfDat.Saccades.ampl(edfDat.Saccades.eye == i & edfDat.Saccades.entime <= recDur & edfDat.Saccades.sttime >= recOffset);
        % ampl = amplitude of saccade (ie distance)
        % there is also phi, which is direction in degrees (ie not rads)
        data = fixOutliers(data);
        % This metric has a theoretical limit.
        % fixOutliers is sometimes too conservative to catch it,
        % so enforce the hard limit post-hoc.
        % Examples of distance > 360 deg would be blinks (may go to inf)
        data(data > 360) = [];
        output = mean(data);
    case 'positionMax'
        % This is probably useless
        A = edfDat.Fixations.time(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        B = edfDat.Fixations.gavx(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        C = edfDat.Fixations.gavy(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        [~, colIdx] = max(A);
        valueInB = B(colIdx);
        valueInC = C(colIdx);
        output = [valueInB; valueInC];
    case 'positionMin'
        % This also seems useless
        A = edfDat.Fixations.time(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        B = edfDat.Fixations.gavx(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        C = edfDat.Fixations.gavy(edfDat.Fixations.eye == i & edfDat.Fixations.entime <= recDur & edfDat.Fixations.sttime >= recOffset);
        [~, colIdx] = min(A);
        valueInB = B(colIdx);
        valueInC = C(colIdx);
        output = [valueInB; valueInC];
    case 'heatmap'
        % This is a 2D matrix, not a single value! Be careful.
        
        % First get the full gaze trajectory for this trial
        dat = selectMetric(edfDat, 'gaze', varargin{:});
        
        % Separate x and y timeseries
        xdat = dat(1,:);
        ydat = dat(2,:);
        clear dat

        % A number >= 1 of pixels to average over
        % 1 = full-resolution, 10 is what Isik used.
        % Another Isik paper averaged 900x900 videos into 20 bins per side,
        % Which is about 2 deg of visual angle.
        binRes = round(deg2pix(2)); % calculate bin size using trig
        % binRes = 80;
        
        % We need to un-flip the gaze for flipped videos
        if flipFlag
            xdat = mirrorX(xdat, scDim(1));
        end

        % Get the data
        output = getHeatmap(xdat, ydat, scDim, binRes);
        
    case 'interp'
        % A QC metric to see what proportion of gaze gets interpolated
        % Since X and Y coordinates are interpolated separately,
        % we take the intexing vector of both, sum them, then average.

        % Get the XY timeseries and convert from uint32 for precision
        xdat = double(edfDat.Samples.gx(i+1,:));
        ydat = double(edfDat.Samples.gy(i+1,:));
        % Interpolate over blinks
        [xdat, blinkx] = censorBlinks(xdat, edfDat);
        [~, blinky] = censorBlinks(ydat, edfDat);
        % Calculate the proportion of gaze samples that were interpolated.
        output = sum(blinkx | blinky) / length(xdat);

    case 'gaze'
        % This is a 4*n matrix covering n timepoints:
        % The first 2 rows are X-Y coordinate pairs
        % that represents gaze position on screen over time,
        % the 3rd row gives the time in ms from onset,
        % and the 4th row gives the video frame number that was active.
        % Not intended as its own metric per se,
        % but gives a consistent way to extract frequently-used data.

        % Get the XY timeseries and convert from uint32 for precision
        xdat = double(edfDat.Samples.gx(i+1,:));
        ydat = double(edfDat.Samples.gy(i+1,:));
        % Do some preprocessing
        xdat = censorBlinks(xdat, edfDat);
        ydat = censorBlinks(ydat, edfDat);

        % Clip any values that remain beyond the screen's dimensions,
        % as they must be artifacts (e.g. poor blink filtering)
        xdat(xdat > scDim(1)) = scDim(1);
        xdat(xdat < 0) = 0;
        ydat(ydat > scDim(2)) = scDim(2);
        ydat(ydat < 0) = 0;

        % Only consider timepoints where the stimulus was visible
        stimPeriod = edfDat.Samples.time >= stimStart & edfDat.Samples.time < stimEnd;
        
        % i is 0 or 1 for left or right eye, so i+1 is 1st or 2nd row.
        % xdat = pickCoordData(edfDat.Samples.gx(:, stimPeriod));
        % ydat = pickCoordData(edfDat.Samples.gy(:, stimPeriod));
        xdat = xdat(stimPeriod);
        ydat = ydat(stimPeriod);
        tdat = double(edfDat.Samples.time(stimPeriod)) - stimStart;

        % We need to un-flip the gaze for flipped videos
        if flipFlag
            xdat = mirrorX(xdat, scDim(1));
        end
        output = [xdat;ydat; tdat];
        output = addframe2gaze(output, edfDat, stimParams);
    case 'tot'
        % Time on Target, aka "triangle time"
        % Percentage of video time spent looking at characters
        output = timeOnTarget(edfDat, metricName, varargin{:});

    case 'blinkrate'
        % Pretty straightforward.
        % Duration is in msec, so 1000x gives you the rate in Hz
        if isempty(edfDat.Blinks)
            numBlinks = 0;
        else
            % Length of edfDat.Blinks will just be 1, so count this way.
            numBlinks = length(edfDat.Blinks.sttime);
        end
        output = 1000 * numBlinks / duration;
    case 'devvec'
        % Deviation of actual scanpath from a heatmap based on motion,
        % based on the locations of highest motion in each video frame.
        % This (hidden) metric returns a vector of binary values over time
        % indicating whether gaze was deviated or not.

        % First, get the scanpath:
        gaze = selectMetric(edfDat, 'gaze', varargin{:});
        
        % Get the stim name from edfDat,
        % and isolate the filename of the video
        stimName = getStimName(edfDat);
        [~,stimName] = fileparts(stimName);
        if flipFlag
            % stimName = erase(stimName, 'f_');
            stimName = stimName(3:end); % erase leading 'f_', but keep later ones
        end
        if ~strcmp(stimName(4:end), '.mov')
            stimName = [stimName '.mov'];
        end
        
        % Use stimName to get the predicted scanpath for this stimulus
        predGaze = motionDeviation(stimName);

        % This will be a set of 2D heatmaps over time.
        % See if the gaze data is within a given threshold of the map.
        % The heatmap is at 60Hz while gaze is around 250 Hz;
        % Use gaze(4,:) (frame index) to temporally align.
        thresh = deg2pix(3);
        
        % predGaze is a huge 3D matrix representing each pixel over time,
        % with 1s saying "this pixel had motion" but mostly 0s for none.
        % We're saving compute by stripping out all those 0s:
        % nonZeroPoints gives the X,Y,frame of the pixels WITH motion
        % so you have a more compact vector with only the relevant data.
        % Likewise, gaze has lots of irrelevant data because we only care
        % about the timepoints when there WAS motion to begin with.
        % So we can also skip any cols from gaze where predGaze is all 0s.
        
        
        [nonZeroY, nonZeroX, frameIdx] = ind2sub(size(predGaze), find(predGaze > 0));
        nonZeroPoints = [nonZeroX, nonZeroY, frameIdx];  % Store (x, y, frame) locations
        motionFrames = unique(frameIdx);
        clear predGaze nonZeroX nonZeroY frameIdx % free memory
        
        % Preallocate output so we can quickly slice results in
        output = single(zeros(1,width(gaze)));
        
        % Check all relevant gaze data for each relevant frame
        for k = 1:numel(motionFrames)
            % Extract the relevant locations in this frame
            frameID = motionFrames(k);
            l = nonZeroPoints(:,3) == frameID;
            XY = nonZeroPoints(l,1:2);
            
            % Extract the relevant gaze points
            l = gaze(4,:) == frameID;
            gazeSub = gaze(1:2,l)';
            
            % Instead of looping over every pixel location,
            % Improve performance by using a "k-d tree search",
            % which finds the nearest motion location to every gaze sample.
            motionTree = KDTreeSearcher(XY);
            [~, dists] = knnsearch(motionTree, gazeSub);
            
            % Now we have the distance of every gaze point from motion.
            % If the NEAREST motion location is too far from gaze,
            % then gaze is deviated from ALL other motion points, too.
            % Index those logicals into your output variable.
            output(l) = dists > thresh;
            
        end
        numGoodGaze = nnz(ismember(gaze(4,:), motionFrames));
        % Insert timestamps - for compatibility w/ getAvgDeviance()
%         output = single(output)';
        output(2,:) = gaze(3,:);
        if nargout > 1
            varargout{1} = numGoodGaze;
        end
    case 'deviance'
        % Get the proportion of timepoints deviated from motion energy,
        % discounting any samples where motion was absent.
        [deviance, numGoodGaze] = selectMetric(edfDat, 'devvec', varargin{:});
        output = nnz(deviance(1,:)) / numGoodGaze;

    case 'similarity'
        % Correlation of scanpath with predicted scanpath,
        % based on the location of highest motion in each video frame.
        % Duplicates a lot of the code used in 'deviance',
        % but here return a single correlation coefficient, not a vector.
        
        % First, get the scanpath:
        gaze = selectMetric(edfDat, 'gaze', varargin{:});
        
        % Now get the predicted scanpath for this stimulus
        % We can extract the stim name from edfDat,
        % but it may have a path attached that we should remove first
        stimName = getStimName(edfDat);
        [~,stimName] = fileparts(stimName);
        if flipFlag
            % stimName = erase(stimName, 'f_');
            stimName = stimName(3:end); % erase leading 'f_', but keep later ones
        end
        if ~strcmp(stimName(4:end), '.mov')
            stimName = [stimName '.mov'];
        end

        predGaze = motionDeviation(gaze, stimName);

        output = corr2(gaze(1:2,:), predGaze);
    otherwise
        error('Unknown metric name %s! aborting', metricName);
end