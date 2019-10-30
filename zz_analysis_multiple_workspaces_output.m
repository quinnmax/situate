
fn = '/Users/Max/Dropbox/Projects/situate/results/monte, pool management/situate_v3_monte_500_alt_workspaces_fold_01_2019.09.03.02.15.35.mat';
d = load(fn);

workspaces_cell = d.workspaces_alternatives;
peak_situation_support = nan(1,numel(workspaces_cell));
peak_true_support = nan(1,numel(workspaces_cell));
true_support_of_returned_workspace = nan(1,numel(workspaces_cell));

for imi = 1:numel(workspaces_cell)
    
    cur_workspaces = workspaces_cell{imi};
    
    true_support_values = arrayfun( @(x) support_functions_situation.geometric_mean_padded( .01 + padarray_to(x.GT_IOU,[1,3],0) ), cur_workspaces );
    peak_true_support(imi) = max( true_support_values );
    
    true_support_of_returned_workspace(imi) = true_support_values( argmax( [cur_workspaces.situation_support] ) );
    
end

figure;
plot([0 1],[0 1],':r'); 
hold on; 
plot([0 1],[.5 .5],':r'); 
plot([.5 .5],[0 1],':r'); 
plot( true_support_of_returned_workspace, peak_true_support,'.b');
hold off
axis([0 1 0 1]);
xlabel('geometric mean of gt ious (returned)')
ylabel('geometric mean of gt ious (peak)')

figure; 
subplot(1,2,1);
hist(true_support_of_returned_workspace,20)
xlabel('geometric mean of gt ious (returned)');
subplot(1,2,2);
hist(peak_true_support,20);
xlabel('geometric mean of gt ious (peak)');


