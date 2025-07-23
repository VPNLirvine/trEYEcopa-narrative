function computeSubscoreCorr(AQtable, varargin)

% computes the correlation between questionnaire subscores, up to three
% input tables

data = AQtable; 
if nargin > 0
    data = [data varargin{1}];
elseif nargin > 1
     data = [data varargin{2}];
end

%compute correlation between input scores
[R, P] = corr(table2array(data), 'Type', 'Pearson', 'Rows', 'complete'); %handles the occasional NaN
labels = data.Properties.VariableNames;


% plot results
figure('Name', 'Correlation among scores')
imagesc(corrData); colorbar;                                     
% colormap('parula'); caxis([-1 1]);                                


set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels, ...
         'YTick', 1:length(labels), 'YTickLabel', labels, ...
         'TickLabelInterpreter', 'none');     

xtickangle(45);                              
title('Correlation Matrix of Dimensions');

for i = 1:length(labels)
    for j = 1:length(labels)
        text(j, i, sprintf('%.2f', R(i,j)), ...
             'HorizontalAlignment', 'center', ...
             'Color', 'k', 'FontSize', 8);
    end
end


% Find and print to screen the "significant" correlations
alpha = .05
fprintf('Significant correlations (alpha = %.3f):\n', alpha);
fprintf('----------------------------------------\n');


[i, j] = find(triu(P < alpha, 1)); % triu with k=1 excludes diagonal
if isempty(i)
    fprintf('No significant correlations found.\n');
else
    for in = 1:length(i)
        row_in = i(in); col_in = j(in);
        label1 = labels{row_in}; label2 = labels{col_in};
        
        fprintf('%s vs %s: r = %.4f (p = %.4f)\n', ...
                label1, label2, R(row_in, col_in), P(row_in, col_in));
    end
end
