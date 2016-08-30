

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
    
    regression_data = {};

    for ci = 1:size(agent_records,1)
    for fi = 1:size(agent_records,2)
    for ii = 1:size(agent_records,3)
        conditioning_list = {};
        for ai = 1:length(agent_records{ci,fi,ii})
            cur_agent = agent_records{ci,fi,ii}(ai);
            cur_regression_data_row = {cur_agent.interest, conditioning_list, cur_agent.support.GROUND_TRUTH, cur_agent.support.unused_classifier_value cur_agent.support.sample_densities};
            if isempty(regression_data)
                regression_data = cur_regression_data_row;
            else
                regression_data(end+1,:) = cur_regression_data_row;
            end
            if cur_agent.support.total >= p_conditions{ci,fi,ii}.thresholds.total_support_provisional
                conditioning_list = [conditioning_list cur_agent.interest];
                conditioning_list = unique(conditioning_list);
            end
        end
        progress(ii,size(agent_records,3),'generating regression data cell array');
    end
    end
    end
    
%end


    
        
        
        
        
        
        
        

    