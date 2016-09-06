

%function situate_experiment_analysis_training_data_run( results_directory, show_failure_examples )
% situate_experiment_analysis_training_data_run( results_directory, show_failure_examples );



%% set data source 

    if ~exist('show_failure_examples','var') || isempty(show_failure_examples)
        show_failure_examples = true;
    end

    while ~exist( 'results_directory', 'var' ) || isempty(results_directory) || ~isdir(results_directory)

        h = msgbox('Select directory containing the results to analyze');
        uiwait(h);
        results_directory = uigetdir(pwd);  

    end

    temp = dir(fullfile(results_directory, '*_training_data_run_*.mat'));
    fn = cellfun( @(x) fullfile(results_directory,x), {temp.name}, 'UniformOutput', false );

    proposals_display_limit = 1000;

    
    
%% reshaping the data 
    
    % gather all p_conditions and p_conditions descriptions
    p_conditions_temp = [];
    p_conditions_descriptions_temp = {};
    agent_records_temp = {};
    workspaces_final_temp = {};  
    fnames_test_images_temp = {};
    % run_data_temp = {};
    
    for fi = 1:length(fn) 
    % file ind
        temp_d = load(fn{fi});
        p_conditions_descriptions_temp = [p_conditions_descriptions_temp temp_d.p_conditions.description];
        for ci = 1:length(temp_d.p_conditions) 
        % condition ind
            % run_data_temp{end+1} = temp_d.run_data(j,:); % this is per
            % image, so doesn't fit into this fold stuation
            p_conditions_temp{end+1} = temp_d.p_conditions(ci);
            agent_records_temp{end+1} = temp_d.agent_records(ci,:);
            workspaces_final_temp{end+1} = {temp_d.workspaces_final{ci,:}};
            fnames_test_images_temp{end+1} = temp_d.fnames_im_test;
        end
    end
    [unique_descriptions, ~] = unique( p_conditions_descriptions_temp );
    num_conditions = length(unique_descriptions);
    
    description_counts = counts(p_conditions_descriptions_temp);
    if ~all(eq(description_counts(1), description_counts)), error('different numbers of runs for different experimental conditions'); end
    num_folds = max(description_counts);
    
    images_per_run = cellfun( @length, workspaces_final_temp );
    if ~all(eq(images_per_run(1),images_per_run)), error('different numbers of images in different runs'); end
    num_images_per_fold = max(images_per_run);
    
    % go from files for folds to indexing
    % basically just get everything stored into condition,fold,image indexing
    
    fnames_test_images         = cell(num_conditions, num_folds, num_images_per_fold );
    workspaces_final           = cell(num_conditions, num_folds, num_images_per_fold );
    agent_records              = cell(num_conditions, num_folds, num_images_per_fold );
    p_conditions_descriptions  = cell(num_conditions, num_folds, num_images_per_fold );
    p_conditions               = cell(num_conditions, num_folds, num_images_per_fold );
    
    for ci = 1:num_conditions
        cur_condition_linear_inds_list = find(strcmp( p_conditions_descriptions_temp, unique_descriptions{ci} ));
        cur_num_folds = length(cur_condition_linear_inds_list);
    for fi = 1:cur_num_folds
        cur_fold_ind = cur_condition_linear_inds_list(fi);
        cur_num_images_in_fold = length(agent_records_temp{cur_fold_ind});
    for ii = 1:cur_num_images_in_fold
        
        fnames_test_images{ci,fi,ii}         = fnames_test_images_temp{           cur_fold_ind }{ii};
        workspaces_final{ci,fi,ii}           = workspaces_final_temp{             cur_fold_ind }{ii};
        agent_records{ci,fi,ii}              = agent_records_temp{                cur_fold_ind }{ii};
        p_conditions_descriptions{ci,fi,ii}  = p_conditions_descriptions_temp{    cur_fold_ind };
        p_conditions{ci,fi,ii}               = p_conditions_temp{                 cur_fold_ind };
        
    end
    end
    end
   
    
    
%% gather some interesting facts 
    
    % [agent_interest, conditioning_list, gt_iou, internal_support, sampling_densities (may be several)
    
    % regression_data
    %   agent_interest, gt_iou, cnn_value(unused), sampling_densities, {workspace_objects,workspace_gt_ious,workspace_internal_support}
    
    % super_flat_data
    %   agent_interest, internal_support, cnn_value, sampling_densities, 
    %   workspace_dog,        workspace_dog_iou, 
    %   workspace_dogwalker,  workspace_dogwalker_iou, 
    %   workspace_leash,      workspace_leash_iou
    
    data_pretty_flat = {};
    data_super_flat = {};
    
    for ci = 1:size(agent_records,1)
    for fi = 1:size(agent_records,2)
    for ii = 1:size(agent_records,3)
        
        cur_workspace_snapshot = {};
        agent_records_current = agent_records{ci,fi,ii};
        inds_remove = cellfun( @isempty, {agent_records_current.interest} );
        agent_records_current(inds_remove) = [];
        
        for ai = 1:length(agent_records_current)
            cur_agent = agent_records_current(ai);
            cur_regression_data_row = {cur_agent.interest, cur_agent.support.GROUND_TRUTH, cur_agent.support.unused_classifier_value cur_agent.support.sample_densities cur_workspace_snapshot};
            
            if isempty(data_pretty_flat)
                data_pretty_flat = cur_regression_data_row;
            else
                data_pretty_flat(end+1,:) = cur_regression_data_row;
            end
            
            super_flat_data_row = { cur_agent.interest, cur_agent.support.GROUND_TRUTH, cur_agent.support.unused_classifier_value, cur_agent.support.sample_densities };
            for oi = 1:length(p_conditions{ci,fi,ii}.situation_objects)
                cur_object = p_conditions{ci,fi,ii}.situation_objects{oi};
                if ~isempty(cur_workspace_snapshot) && ismember(cur_object,cur_workspace_snapshot(:,1))
                    existing_entry_row = find(strcmp(cur_agent.interest,cur_workspace_snapshot(:,1)));
                    super_flat_data_row(end+1:end+2) = {true; cur_workspace_snapshot{existing_entry_row,2}}; % present, and the gt iou
                else
                    super_flat_data_row(end+1:end+2) = {false; 0 };
                end
            end
            if isempty(data_super_flat)
                data_super_flat = super_flat_data_row;
            else
                data_super_flat(end+1,:) = super_flat_data_row;
            end
                
            
            % update the running workspace snapshot (by just implementing it's logic)
            if cur_agent.support.total >= p_conditions{ci,fi,ii}.thresholds.total_support_provisional
            
                proposed_workspace_snapshot_row = {cur_agent.interest, cur_agent.support.GROUND_TRUTH, cur_agent.support.unused_classifier_value};
                
                if isempty(cur_workspace_snapshot)
                    cur_workspace_snapshot = proposed_workspace_snapshot_row;
                elseif ismember(cur_agent.interest,cur_workspace_snapshot(:,1))
                    existing_entry_row = find(strcmp(cur_agent.interest,cur_workspace_snapshot(:,1)));
                    existing_entry_total_support = cur_workspace_snapshot{existing_entry_row,2};
                    if cur_agent.support.total > existing_entry_total_support
                        cur_workspace_snapshot(existing_entry_row,:) = proposed_workspace_snapshot_row;
                    end
                else
                    cur_workspace_snapshot(end+1,:) = proposed_workspace_snapshot_row;
                end
                
            end
                
        end % end agent index
        progress(ii,size(agent_records,3),'generating regression data cell array');
        
    end
    end
    end
    
    about_data_pretty_flat = {'agent interest','gt iou (used for workspace checkin)', 'cnn output (not used)','sample densities', 'workspace snapshot (rows are same format)'};
    about_data_super_flat  = {'agent_interest','gt_iou (used)','cnn output (not used)','sampled_densities','is_situation_ob_1_in_workspace','gt_iou','is_situation_ob_2_in_workspace','gt_iou','is_situation_ob_3_in_workspace','gt_iou'};
    situation_objects = p_conditions{1,1,1}.situation_objects;
    
    fname_full = fullfile(results_directory,'results_data_restructured');
    save(fname_full, ...
        'data_pretty_flat','about_data_pretty_flat',...
        'data_super_flat','about_data_super_flat',...
        'situation_objects');


%% super basic visualizing

h = msgbox('Select directory containing the results to analyze');
uiwait(h);
results_directory = uigetdir(pwd);  
fname_full = fullfile(results_directory,'results_data_restructured');

data = load(fname_full);
data_super_flat = data.data_super_flat;
%data_super_flat = data.super_flat_data;
situation_objects = data.situation_objects;

inds_dogwalker  = strcmp( 'dogwalker',  data_super_flat(:,1) );
inds_dog        = strcmp( 'dog',        data_super_flat(:,1) );
inds_leash      = strcmp( 'leash',      data_super_flat(:,1) );
inds_workspace_dogwalker = [data_super_flat{:,5}];
inds_workspace_dog       = [data_super_flat{:,7}];
inds_workspace_leash     = [data_super_flat{:,9}];

%% look at correlation between classifier output and IOU, nothing about other stuff

figure
for oi = 1:length(situation_objects)
    
    cur_object = situation_objects{oi};
    cur_object_inds = strcmp(cur_object,data_super_flat(:,1));
    
    subplot(1,length(situation_objects),oi);
    plot( [data_super_flat{cur_object_inds,3}], [data_super_flat{cur_object_inds,2}], '.');
    [corrcoeffs,p] = corrcoef([data_super_flat{cur_object_inds,3}], [data_super_flat{cur_object_inds,2}]);
    title([cur_object]);
    ylabel('gt iou'); 
    xlabel({'cnn score',['R = ' num2str(corrcoeffs(1,2))]});
    xlim([0,1]); ylim([0,1])
    
end



%% go through each conditioning state. describe, count, and keep indices

conditioning_states = all_combinations(3);
object_condition_inds        = cell(  length(situation_objects), size(conditioning_states,1) );
object_condition_count       = zeros( length(situation_objects), size(conditioning_states,1) );
object_condition_description = cell(  length(situation_objects), size(conditioning_states,1) );

for oi = 1:length(situation_objects)
    
    cur_object = situation_objects{oi};
    cur_object_inds = strcmp(cur_object,data_super_flat(:,1));
    
    for ci = 1:size(conditioning_states,1)
        cur_conditioning_state = conditioning_states(ci,:);
        if cur_conditioning_state( find(strcmp(situation_objects,cur_object)) )
            % this is conditioning on itself, so we'll just ignore these
        else
            cur_conditioning_mat = [([data_super_flat{:,5}]==cur_conditioning_state(1))' ...
                                    ([data_super_flat{:,7}]==cur_conditioning_state(2))' ...
                                    ([data_super_flat{:,9}]==cur_conditioning_state(3))' ];
            % we won't accept or reject based on the object of interest
            % being in the workspace. that has no bearing
            cur_conditioning_mat(:,find(strcmp(situation_objects,cur_object))) = true;
            
            condition_inds = all( cur_conditioning_mat, 2 );
                        
            object_condition_inds{oi,ci}        = and(cur_object_inds, condition_inds);
            object_condition_count(oi,ci)       = sum(object_condition_inds{oi,ci});
            object_condition_description{oi,ci} = [cur_object ' given ' ['(' sprintf(' %s ',situation_objects{cur_conditioning_state}) ')']];
        end
            
    end
    
end

%% play with the regression stuff

%dist = 'binomial';
%link = 'logit';

dist = 'normal';
link = 'identity';

object_condition_inds = object_condition_inds(:);
object_condition_count = object_condition_count(:);
object_condition_description = object_condition_description(:);
inds_remove = cellfun( @isempty, object_condition_inds);
object_condition_inds(inds_remove) = [];
object_condition_count(inds_remove) = [];
object_condition_description(inds_remove) = [];

[~,display_order] = sort(object_condition_description);

figure('Name','cnn and densities');
for di = 1:length(display_order)
    oci = display_order(di);
    cur_regression_target = [data_super_flat{object_condition_inds{oci},2}]';
    
    cur_regression_data_a = [data_super_flat{object_condition_inds{oci},3}]';
    cur_regression_data_b = cell2mat(data_super_flat(object_condition_inds{oci},4));
    cur_regression_data_unnormalized   = [cur_regression_data_a cur_regression_data_b];
    %mu = mean(cur_regression_data_unnormalized);
    %sigma = std(cur_regression_data_unnormalized);
    %n = size(cur_regression_data_unnormalized,1);
    %cur_regression_data = repmat(sigma,n,1) .* (cur_regression_data_unnormalized - repmat(mu,n,1));
    cur_regression_data = cur_regression_data_unnormalized;
    
    B = glmfit( cur_regression_data, cur_regression_target, dist);
    y_fit = glmval( B, cur_regression_data, link );
    r = corrcoef(y_fit,cur_regression_target);
    
    subplot(3,4,di);
    plot(y_fit,cur_regression_target,'.');
    xlabel({'regression output',['r = ' num2str(r(1,2))]});
    ylabel('regression target');
    title({object_condition_description{oci},['num samples = ' num2str(object_condition_count(oci))]});
end


figure('Name','just cnn');
for di = 1:length(display_order)
    oci = display_order(di);
    cur_regression_target = [data_super_flat{object_condition_inds{oci},2}]';
    
    cur_regression_data_a = [data_super_flat{object_condition_inds{oci},3}]';
    cur_regression_data_unnormalized   = cur_regression_data_a;
    %mu = mean(cur_regression_data_unnormalized);
    %sigma = std(cur_regression_data_unnormalized);
    % = size(cur_regression_data_unnormalized,1);
    %cur_regression_data = repmat(sigma,n,1) .* (cur_regression_data_unnormalized - repmat(mu,n,1));
    cur_regression_data = cur_regression_data_unnormalized;
    
    B = glmfit( cur_regression_data, cur_regression_target, dist);
    y_fit = glmval( B, cur_regression_data, link );
    r = corrcoef(y_fit,cur_regression_target);
    
    subplot(3,4,di);
    plot(y_fit,cur_regression_target,'.');
    xlabel({'regression output',['r = ' num2str(r(1,2))]});
    ylabel('regression target');
    title({object_condition_description{oci},['num samples = ' num2str(object_condition_count(oci))]});
end
    

%% play with the regression stuff
% this time, no splitting up by conditioning state.
% just the object type, and the location density

%dist = 'binomial';
%link = 'logit';

dist = 'normal';
link = 'identity';

figure('Name','cnn and densities');
for oi = 1:length(situation_objects)
    
    cur_object = situation_objects{oi};
    cur_inds   = strcmp(cur_object,data_super_flat(:,1));
    
    regression_target = [data_super_flat{cur_inds,2}]';
    regression_data_a = [data_super_flat{cur_inds,3}]';
    regression_data_b = cellfun( @(x) x(1), data_super_flat(cur_inds,4) );
    regression_data   = [regression_data_a, regression_data_b];
    
    B = glmfit( regression_data, regression_target, dist);
    y_fit = glmval( B, regression_data, link );
    r = corrcoef(y_fit,regression_target);
    
    subplot(1,3,oi);
    plot(y_fit,regression_target,'.');
    xlabel({'regression output',['r = ' num2str(r(1,2))]});
    ylabel('regression target');
    title(cur_object);
   
end


dist = 'normal';
link = 'identity';

figure('Name','cnn alone');
for oi = 1:length(situation_objects)
    
    cur_object = situation_objects{oi};
    cur_inds   = strcmp(cur_object,data_super_flat(:,1));
    
    regression_target = [data_super_flat{cur_inds,2}]';
    regression_data_a = [data_super_flat{cur_inds,3}]';
    %regression_data_b = cellfun( @(x) x(1), data_super_flat(cur_inds,4) );
    %regression_data   = [regression_data_a, regression_data_b];
    regression_data = regression_data_a;
    
    B = glmfit( regression_data, regression_target, dist);
    y_fit = glmval( B, regression_data, link );
    r = corrcoef(y_fit,regression_target);
    
    subplot(1,3,oi);
    plot(y_fit,regression_target,'.');
    xlabel({'regression output',['r = ' num2str(r(1,2))]});
    ylabel('regression target');
    title(cur_object);
   
end


dist = 'normal';
link = 'identity';

figure('Name','location density alone');
for oi = 1:length(situation_objects)
    
    cur_object = situation_objects{oi};
    cur_inds   = strcmp(cur_object,data_super_flat(:,1));
    
    regression_target = [data_super_flat{cur_inds,2}]';
    %regression_data_a = [data_super_flat{cur_inds,3}]';
    regression_data_b = cellfun( @(x) x(1), data_super_flat(cur_inds,4) );
    %regression_data   = [regression_data_a, regression_data_b];
    regression_data = regression_data_b;
    
    B = glmfit( regression_data, regression_target, dist);
    y_fit = glmval( B, regression_data, link );
    r = corrcoef(y_fit,regression_target);
    
    subplot(1,3,oi);
    plot(y_fit,regression_target,'.');
    xlabel({'regression output',['r = ' num2str(r(1,2))]});
    ylabel('regression target');
    title(cur_object);
   
end

    
        
        
        
        
        
        
        

    