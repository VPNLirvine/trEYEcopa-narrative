function pths = specifyPaths(varargin)

% Define base directory everything else is relative to
% Allow an input to serve as the base dir
if nargin == 0
    % Default value is the location of this function
    pths.base = fileparts(mfilename("fullpath"));
else
    base = varargin{1};
    assert(ischar(base), 'Input to specifyPaths must be a string!')
    assert(exist(base, 'dir') > 0, 'Provided path %s does not exist!', base);

    % In case input is e.g. '..', convert to an actual path
    [~, info] = fileattrib(base);
    % Store path
    pths.base = info.Name;
end

pths.analysis = fullfile(pths.base, 'Analysis');

pths.eye = fullfile(pths.base, 'data/eyetracking/source/');
    pths.eye_data = fullfile(pths.eye, 'data/');
    pths.eye_pilot = fullfile(pths.eye, 'pilot/');

pths.eye_mat = fullfile(pths.base, 'data/eyetracking/derivatives/');
    pths.eye_mat_data = fullfile(pths.eye_mat, 'data/');
    pths.eye_mat_pilot = fullfile(pths.eye_mat, 'pilot/');


pths.narr_wav = fullfile(pths.base, 'data/narrations/source/');
    pths.narr_wav_data = fullfile(pths.narr_wav, 'data/');
    pths.narr_wav_pilot = fullfile(pths.narr_wav, 'pilot/');

pths.narr = fullfile(pths.base, 'data/narrations/derivatives/');
    pths.narr_data = fullfile(pths.narr, 'data/');
    pths.narr_pilot = fullfile(pths.narr, 'pilot/');

pths.beh = fullfile(pths.base, 'data/beh/'); % 
    pths.beh_data = fullfile(pths.beh, 'data/');
    pths.beh_pilot = fullfile(pths.beh, 'pilot/');


pths.frames = fullfile(pths.base, 'frames');
pths.edf = fullfile(pths.base, 'edfImport');
pths.edfalt = fullfile(pths.base, 'edf_alt');

pths.pos = fullfile(pths.analysis, 'Position'); % adjusted position data
pths.map = fullfile(pths.analysis, 'motionMaps'); % stim motion heatmaps

pths.fixcheck = fullfile(pths.base, 'fixation_checks'); % calibration
