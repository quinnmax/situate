function situate_experiment_analysis_nouveau( input )

    % file
    input = '/Users/Max/Dropbox/Projects/situate/results/dogwalking_dogwalking, agent pool policy playing_2017.10.17.21.48.34/stable pool, low provisional threshold, even total support, run all iterations_fold_01_2017.10.17.22.28.24.mat';
    % directory
    %input = '/Users/Max/Dropbox/Projects/situate/results/dogwalking_dogwalking, agent pool policy playing_2017.10.17.21.48.34/';
    % cell
    %input = {'/Users/Max/Dropbox/Projects/situate/results/dogwalking_dogwalking, agent pool policy playing_2017.10.17.21.48.34/stable pool, low provisional threshold, even total support, run all iterations_fold_01_2017.10.17.22.28.24.mat'};
    
    %% process the input, get cell of mat file names
    
        if ~exist('input','var') || isempty(input)
            h = msgbox('Select directory containing the results to analyze');
            uiwait(h);
            results_directory = uigetdir(pwd);
            if isempty(results_directory) || isequal(results_directory,0), return; end
        end

        if isdir( input )
            temp = dir(fullfile(input, '*.mat'));
            mat_file_names = cellfun( @(x) fullfile(results_directory,x), {temp.name}, 'UniformOutput', false );
        end

        if iscell( input )
            mat_file_names = input;
        end

        if exist( input, 'file' )
            mat_file_names = {input};
        end
    
    %% group on condition
    
        condition_structs_unique = {};
        condition_struct_assignments = zeros(1,length(mat_file_names));
        for fi = 1:length(mat_file_names)
            temp = load( mat_file_names{fi}, 'p_condition' );
            cur_condition = temp.p_condition;
            cur_condition.seed_test = [];
            if fi > 1
                error('need to check on comparing p_conditions. at least need to ');
            end
            
            cur_condition_assignment = find( cellfun( @(x) isequal( cur_condition, x ), condition_structs_unique ) );
            if isempty(cur_condition_assignment)
                condition_structs_unique{end+1} = cur_condition;
                condition_struct_assignments(fi) = length(condition_structs_unique);
            else
                condition_struct_assignments(fi) = cur_condition_assignment;
            end
        end
        num_conditions = length(condition_structs_unique);
        
        
        
    %% cheap analysis stuff
        
        % final workspaces by condition
            workspaces_final = cell( 1, num_conditions );
            for ci = 1:num_conditions
                cur_mat_fnames = mat_file_names(eq(ci,condition_struct_assignments));
                temp = cellfun( @(x) load( x, 'workspaces_final' ), cur_mat_fnames );
                workspaces_final{ci} = [temp.workspaces_final];
            end

        % detections at various IOU thresholds
            num_thresholds = 10;
            iou_thresholds = sort(unique([linspace(0,1,num_thresholds+1) .5])); % make sure .5 is in there
            iou_thresholds = iou_thresholds(2:end);
            num_thresholds = length(iou_thresholds);
            detections_at_iou = zeros( num_thresholds, num_situation_objects+1 );
            for ti  = 1:num_thresholds
                for oi  = 1:num_situation_objects
                    detections_at_iou(ti,oi) = sum( ge( final_ious(:,oi), iou_thresholds(ti) ) );
                end
                detections_at_iou(ti,end) = sum( all( final_ious >= iou_thresholds(ti), 2 ) );
            end
            
        % final IOUs for objects
        % final internal support for objects
            final_ious = zeros( num_images, num_situation_objects );
            for imi = 1:num_images
            for oi  = 1:num_situation_objects
                wi  = strcmp( situation_objects{oi},workspaces_final(imi).labels);
                if any(wi)
                    final_ious(imi,oi) = workspaces_final(imi).GT_IOU(wi);
                end
            end
            end

        
    %% expensive analysis stuff (first iteration over threshold
    
        do_the_expensive_thing = false;
        if do_the_expensive_thing

            iter_over_thresh = cell( 1, num_conditions );
            iou_thresholds = [];
            for ci = 1:num_conditions
                cur_condition_mat_fnames = mat_file_names(eq(condition_struct_assignments,ci));
                [iter_over_thresh{ci}, ~, iou_thresholds] = first_iteration_over_threshold( mat_file_names );
            end

        end
        
        display('here');

    
    
end



function [output, output_desc, iou_thresholds] = first_iteration_over_threshold( mat_file_names )
    
    % [output, output_desc, iou_thresholds] = first_iteration_over_threshold( mat_file_names )
    %
    % mat_file_names:
    %   cell array of results mat file names
    % 
    % output(image_index, object_index, threshold_index): 
    %   first iteration with gt_iou and total_support over threshold
    %   there's an extra entry for full situation detections after the last object index
    %
    % output_desc: just a reminder
    % iou_thresholds: mat of the thresholds used
    
    temp = load( mat_file_names{1}, 'p_condition');
    params = temp.p_condition;
    num_situation_objects = length( params.situation_objects );

    temp = cellfun( @(x) load(x,'agent_records'), mat_file_names );
    agent_records = [temp.agent_records];
    agent_records = [agent_records{:}]';

    num_thresholds = 10;
    iou_thresholds = sort(unique([linspace(0,1,num_thresholds+1) .5])); % make sure .5 is in there
    iou_thresholds = iou_thresholds(2:end);
    num_thresholds = length(iou_thresholds);
    num_images     = size(agent_records,1);

    % for each image, object, iou threshold
    % when was the first box with a) confidence over that threshold, and b) gt iou over that threshold
    output = zeros( num_images, num_situation_objects+1, num_thresholds );
    output_desc = {'image index, object index, iou threshold index';'checks for total support over threshold AND gt iou over threshold'};

        for ii = 1:num_images
        for ti = 1:num_thresholds
            
            for oi = 1:num_situation_objects

                iterations_of_interest = find([agent_records(ii,:).interest] == oi);
                temp             = [agent_records(ii,:).support];
                temp             = temp(iterations_of_interest);
                %internal_support = [temp.internal];
                %external_support = [temp.external];
                total_support    = [temp.total];
                gt_iou           = [temp.GROUND_TRUTH];

                % first with an actual gt_iou over threshold 
                % and total support over threshold
                first_over_threshold = find( ge( gt_iou, iou_thresholds(ti) ) & ge( total_support, iou_thresholds(ti) ), 1, 'first' );

                if ~isempty(first_over_threshold)
                    output(ii,oi,ti) = iterations_of_interest( first_over_threshold );
                else
                    output(ii,oi,ti) = nan;
                end
            
            end
            
            % full situation entry
            if any(isnan(output(ii,1:num_situation_objects,ti)))
                output(ii,end,ti) = nan;
            else
                output(ii,end,ti) = max(output(ii,1:num_situation_objects,ti));
            end
        
        end
        progress( ii, num_images, ['first iteration over threshold: ' params.description]);
        end
        
end


        




