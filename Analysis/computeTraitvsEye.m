function computeTraitvsEye(traitTable, eyeData)

numSubs_trait = size(traitTable, 1);
numSubs_eye = size(eyeData, 1);

if numSubs_trait ~= numSubs_eye
    fprintf(1, '\nError: %i subjects in trait table does not match %i subjects in gaze data\n', numSubs_trait, numSubs_eye);


else
    subScore_labels = traitTable.Properties.VariableNames;
    subList = unique(eyeData.Subject);

    % figure this out
    % [var3, yl3, distTxt3] = getGraphLabel(aqt);


    % Loop over all subscales available
    for t = 1:size(traitTable, 2) % trait subscales

        subscore(s) = traitTable{:, t};
        subscoreLabel

        % Calculate correlations
        aq2eye = []; % clear on each loop
        [aq2eye(1), aq2eye(2) ]= corr(subscore, eyeCol, 'Type', 'Spearman', 'rows', 'complete');

        % Plot
        figure('Name', 'Gaze metric by AQ');
        scatter(subscore, eyeCol);
        title(sprintf('Across %i subjects, strength of relationship \x03C1 = %0.2f, p = %0.4f', numSubs, aq2eye(1), aq2eye(2)));
        xlabel(subScore_labels{t});
        ylabel(['Gaze ' gazeMetric]);

        % Report the correlation score to command window
        fprintf(1, '\n\nCorrelation between %s and average %s within subject:\n', var3, subScore_labels{t})
        fprintf(1, '\tPearson''s r = %0.2f, p = %0.4f\n', aq2eye(1) aq2eye(2));

        % Histograms
        figure('Name', 'Histograms of gaze metric and subscores');
        subplot(1,2,1); histogram(data.Eyetrack);
        title('Gaze')
        xlabel(gazeMetric);

        subplot(1,2,2), histogram(subscore, 'BinEdges', 0:5:50);
        xlabel(subScore_labels{t});
        title(subScore_labels{t});

    end % for each subscale
end