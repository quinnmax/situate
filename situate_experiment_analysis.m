

function situate_experiment_analysis( results_directory )



if ~exist( 'results_directory', 'var' ) || ~isdir(results_directory)

    % from a directory
    results_directory = '/Users/Max/Desktop/experiment_name_22-Jul-2016/';
    
end

temp = dir(fullfile(results_directory, '*.mat'));
fn = cellfun( @(x) fullfile(results_directory,x), {temp.name}, 'UniformOutput', false );



% explicit filenames
% fn  =[];  
% fn{end+1} = '/Users/Max/Dropbox/Projects/situate/situate_experiment_mm_1_results2016.05.05.12.37.44.mat';
% fn{end+1} = '/Users/Max/Dropbox/Projects/situate/situate_experiment_mm_1_results2016.05.05.13.58.21.mat';
% fn{end+1} = '/Users/Max/Dropbox/Projects/situate/situate_experiment_mm_1_results2016.05.05.15.55.05.mat';
% fn{end+1} = '/Users/Max/Dropbox/Projects/situate/situate_experiment_mm_1_results2016.05.05.19.21.37.mat';
% fn{end+1} = '/Users/Max/Dropbox/Projects/situate/situate_experiment_mm_1_results2016.05.06.10.11.53.mat';





    
    
proposals_display_limit = 1000;
    


%% reshaping the data
    
    
    % gather all p_conditions and p_conditions descriptions
    p_conditions_temp = [];
    p_conditions_descriptions_temp = {};
    workspace_entry_event_logs_temp = {};
    workspaces_final_temp = {};  
    fnames_test_images_temp = {};
    
    for fi = 1:length(fn);
        temp_d = load(fn{fi});
        for j = 1:length(temp_d.p_conditions)
            p_conditions_temp{end+1} = temp_d.p_conditions(j);
            p_conditions_descriptions_temp{end+1} = temp_d.p_conditions_descriptions{j};
            workspace_entry_event_logs_temp{end+1} = temp_d.workspace_entry_event_logs(j,:);
            workspaces_final_temp{end+1} = {temp_d.workspaces_final{j,:}};
            fnames_test_images_temp{end+1} = temp_d.fnames_im_test;
        end
    end
    
    [unique_descriptions, ~] = unique( p_conditions_descriptions_temp );
    num_methods = length(unique_descriptions);
    
    description_counts = counts(p_conditions_descriptions_temp);
    if ~all(eq(description_counts(1), description_counts)), error('different numbers of runs for different experimental conditions'); end
    num_folds = max(description_counts);
    
    images_per_run = cellfun( @length, workspaces_final_temp );
    if ~all(eq(images_per_run(1),images_per_run)), error('different numbers of images in different runs'); end
    num_images_per_fold = max(images_per_run);
    
    
    
    % reshape everything
    
    fnames_test_images         = cell(num_methods, num_folds, num_images_per_fold );
    workspaces_final           = cell(num_methods, num_folds, num_images_per_fold );
    workspace_entry_event_logs = cell(num_methods, num_folds, num_images_per_fold );
    p_conditions_descriptions  = cell(num_methods, num_folds, num_images_per_fold );
    p_conditions               = cell(num_methods, num_folds, num_images_per_fold );
    
    if ~isfield( p_conditions_temp{1}, 'situation_objects')
        required_objects = {'dog','person','leash'};
        warning('situation_objects not set, using {dog,person,leash}');
    else
        required_objects = p_conditions_temp{1}.situation_objects;
    end
    
    checkin_threshold     = p_conditions_temp{1}.total_support_threshold_2;
    detection_times       = inf(   num_methods, num_folds, num_images_per_fold, length(required_objects) );
    detection_sequence    = cell(  num_methods, num_folds, num_images_per_fold, length(required_objects) );
    final_IOUs            = zeros( num_methods, num_folds, num_images_per_fold, length(required_objects) );
    successful_completion = false( num_methods, num_folds, num_images_per_fold );
    
    for mi = 1:num_methods
        cur_method_linear_inds_list = find(strcmp( p_conditions_descriptions_temp, unique_descriptions{mi} ));
        cur_num_folds = length(cur_method_linear_inds_list);
    for fi = 1:cur_num_folds
        cur_fold_ind = cur_method_linear_inds_list(fi);
        cur_num_images_in_fold = length(workspace_entry_event_logs_temp{cur_fold_ind});
    for ii = 1:cur_num_images_in_fold
        
        fnames_test_images{mi,fi,ii}         = fnames_test_images_temp{           cur_fold_ind }{ii};
        workspaces_final{mi,fi,ii}           = workspaces_final_temp{             cur_fold_ind }{ii};
        workspace_entry_event_logs{mi,fi,ii} = workspace_entry_event_logs_temp{   cur_fold_ind }{ii};
        p_conditions_descriptions{mi,fi,ii}  = p_conditions_descriptions_temp{    cur_fold_ind };
        p_conditions{mi,fi,ii}               = p_conditions_temp{    cur_fold_ind };
        
        [unique_detection_labels,~,label_assignments] = unique( workspace_entry_event_logs{mi,fi,ii}(:,2) );
        was_over_threshold = ge( [workspace_entry_event_logs{mi,fi,ii}{:,4}], checkin_threshold );
        % if a box is improved, just keep the time for the first acceptable detection
        % so we're just looking for the first detections of each object
        % type (that's over the detection threshold)
        first_detections = inf(1,length(unique_detection_labels));
        first_detections_labels = cell(1,length(unique_detection_labels));
        for label_type_ind = 1:length(unique_detection_labels)
            
            first_detection_row = find(and( eq(label_assignments,label_type_ind), was_over_threshold' ), 1,'first');
            if ~isempty(first_detection_row)
                first_detections(label_type_ind) = workspace_entry_event_logs{mi,fi,ii}{first_detection_row,1};
                first_detections_labels{label_type_ind} = unique_detection_labels{label_type_ind};
            else
                first_detections(label_type_ind) = inf;
            end
              
            final_detection_row = find(eq(label_assignments,label_type_ind),1,'last');
            final_IOUs(mi,fi,ii,label_type_ind) = workspace_entry_event_logs{mi,fi,ii}{final_detection_row,4};
            
        end
        
        [first_detections, sort_inds] = sort(first_detections,'ascend');
        first_detections(end+1:3)     = inf;
        detection_times(mi,fi,ii,:)   = first_detections;
        detection_sequence(mi,fi,ii,1:length(sort_inds))  = first_detections_labels(sort_inds);
        
        if ~any(cellfun(@isempty, first_detections_labels)) ...
           && length( intersect( first_detections_labels, required_objects) ) == length(required_objects)
            successful_completion(mi,fi,ii) = true;
        else
            successful_completion(mi,fi,ii) = false;
        end        
        
    end
    end
    end
    
    
    inds_found_object_type = [];
    for oi = 1:length(required_objects)
        inds_found_object_type.(required_objects{oi}) = strcmp( detection_sequence, required_objects{oi} );
    end
    
    
    
% use min for time to first detections, median for time to second detection, 
% and max for time to third detection
    first_detections  = min(     detection_times, [], 4);
    second_detections = median(  detection_times,     4);
    third_detections  = max(     detection_times, [], 4);
    
  
        
    
% reshape for detections as a function of number of proposals
    max_proposals = max(cellfun( @(x) x.num_iterations, p_conditions_temp));
    detections_at_num_proposals = zeros( num_methods, num_folds, max_proposals );
        
    for mi = 1:num_methods
    for fi = 1:num_folds
    for ii = 1:num_images_per_fold
        
        cur_detection = third_detections(mi,fi,ii);
        if ~isinf(cur_detection)
            detections_at_num_proposals(mi,fi,cur_detection:end) = detections_at_num_proposals(mi,fi,cur_detection:end) + 1;
        end
        
    end
    end
    end
    
% get detections as function of proposals, grouped over folds
    max_proposals = max(cellfun( @(x) x.num_iterations, p_conditions_temp));
    detections_at_num_proposals_mu    = zeros( num_methods, max_proposals );
    detections_at_num_proposals_sigma = zeros( num_methods, max_proposals );
    for mi = 1:num_methods
       
        detections_at_num_proposals_mu(mi,:)    = mean( detections_at_num_proposals(mi,:,:) );
        detections_at_num_proposals_sigma(mi,:) = std(  detections_at_num_proposals(mi,:,:) );
    
    end
    
    detections_at_num_proposals_sum = sum(detections_at_num_proposals_mu,2);
    
    

%% define methods to include, set their order, and define the line specifications

%include_methods = find([1 1 0, 0 0 1, 0 0 0, 1 1 1, 1]);
include_methods = find(true(1,length(unique_descriptions)));

% assign colors to methods
colors = cool(length(include_methods));
%colors = color_fade([1 0 1; 0 0 0; 0 .75 0], length(include_methods ) );
%colors = sqrt(colors);

linespec = {'-','--','-.'};
linespec = repmat(linespec,1,ceil(length(include_methods)/length(linespec)));

detections_at_num_proposals_squeezed = squeeze(sum(detections_at_num_proposals,  2));
[~,sort_order] = sort(sum(detections_at_num_proposals_squeezed(:,1:proposals_display_limit),2), 'descend');

display_order = [];
for mi = 1:length(sort_order)
    if ismember( sort_order(mi), include_methods)
        display_order = [display_order sort_order(mi)];
    end
end



%% figure without bounds

    h2 = figure();
    h2.Color = [1 1 1];
    hold on;
    ci = 1; % color index
    
    for i = 1:length(display_order);
    % for mi = 1:num_methods
        mi = display_order(i);
        plot( detections_at_num_proposals_squeezed(mi,:), 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
    end
    hold off;
    
    hold on;
        plot([0 max_proposals], [num_images_per_fold * num_folds, num_images_per_fold * num_folds], '--black')
    hold off;
    
    box(h2.CurrentAxes,'on');
    
    xlabel(  'Iterations' );
    ylabel({ 'Completed Situation Detections', '(Cumulative)' });
 
    xlim([0 max_proposals]);
    xlim([0 proposals_display_limit])  
    ylim([0 1.1*num_images_per_fold*num_folds]);
    
    % legend(unique_descriptions(sort_order),'Location','Northeast');
    title_string = 'location prior, box prior, conditioning';
    h_temp = legend(unique_descriptions(display_order),'Location','eastoutside','FontName','FixedWidth');
    h_temp.Title.String = title_string;
    h_temp.FontSize = 8;
   
    h2.Position = [440 537 560 220];
    print(h2,'situate_experiment_figure_2','-r300', '-dpdf' )   
     
    
    
%% medians over methods

    detections_at_num_proposals_squeezed = squeeze(sum(detections_at_num_proposals,  2));
    
    clear temp_a temp_b temp_c
    fprintf('Median time to first detection\n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(first_detections(mi,:,:),1,[]);
        temp_b = prctile(temp_a,50);
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(second_detections(mi,:,:),1,[]);
        temp_b = prctile( temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time to third detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(third_detections(mi,:,:),1,[]);
        temp_b = prctile( temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time from first to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(first_detections(mi,:,:),1,[]);
        temp_b = reshape(second_detections(mi,:,:),1,[]);
        miss_list_c = prctile( temp_b - temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, miss_list_c );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time from second to third detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(second_detections(mi,:,:),1,[]);
        temp_b = reshape(third_detections(mi,:,:),1,[]);
        miss_list_c = prctile( temp_b - temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, miss_list_c );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Number of failed detections \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(third_detections(mi,:,:),1,[]);
        temp_b = sum( gt(temp_a,proposals_display_limit) );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*d\n',10, temp_b );
    end
    fprintf('\n\n');
 
    
    
%% report on failed detections
        
p = p_conditions{1,1,1};

if ~isfield(p, 'situation_objects')
    p.situation_objects = required_objects;
    warning('situation_objects not set, using {dog,person,leash}');
end

completion_iteration    = inf( size(workspace_entry_event_logs));
final_workspace_snippet = cell(size(workspace_entry_event_logs));
ending_support = cell(1,size(workspace_entry_event_logs,1));
for mi = 1:size(workspace_entry_event_logs,1) % method
for fi = 1:size(workspace_entry_event_logs,2) % fold
for ii = 1:size(workspace_entry_event_logs,3) % image
    [completion_iteration(mi,fi,ii), ...
     final_workspace_snippet{mi,fi,ii}] = ...
        situate_workspace_entry_event_log_to_completion_time( ...
            workspace_entry_event_logs{mi,fi,ii}, ...
            p, 1000 );
end
end
    ending_support{mi} = cell2mat(final_workspace_snippet(mi,:)');
end
  


%% draw the figures

    % for mi = 1:num_methods
    for mi = find(strcmp(unique_descriptions,'salience, learned, yes'));

        failed_completions_logical_index = squeeze(   gt( completion_iteration(mi,:,:),  proposals_display_limit   ) );
        failed_completions      = sum( failed_completions_logical_index(:));
        [failed_i, failed_j] = find(failed_completions_logical_index);

        failures_count = [];
        zero_iou_counts = [];
        provisional_only_counts = [];
        for oi = 1:length(p.situation_objects)
            zero_iou_counts.(p.situation_objects{oi})           = sum( eq(ending_support{mi}(:,oi), 0 ) );
            provisional_only_counts.(p.situation_objects{oi})   = sum( lt(ending_support{mi}(:,oi), p.total_support_threshold_2 ) .* gt(ending_support{mi}(:,oi), 0 ) );
            failures_count.(p.situation_objects{oi})            = sum( lt(ending_support{mi}(:,oi), p.total_support_threshold_2 ) );
        end
        
        examples_num_rows = 3;
        examples_num_cols = 5;
        [miss_list_fi,miss_list_ii] = find(failed_completions_logical_index);
        num_examples_per_fig = examples_num_rows * examples_num_cols;
        for i = 1:length(miss_list_fi)

            if mod(i,num_examples_per_fig) == 1
                figure;
                subplot2(examples_num_rows + 1,examples_num_cols, 1,1,1,examples_num_cols);
                h = draw_box([0 0 1 1],'xywh');
                t = {};
                t{1} = unique_descriptions{mi};
                t{2} = sprintf('number images not completed:  %*d', 3, failed_completions );

                for oi = 1:length(p.situation_objects)
                    t{2+oi} = sprintf('missed %s: %*d', p.situation_objects{oi}, 3, sum(lt(ending_support{mi}(:,oi),p.total_support_threshold_2)) );
                end

                h_temp = text(.1,.5,t);
                h_temp.FontName = 'MonoSpaced';
                h.Parent.Visible = 'off';
            end


            row = floor((mod(i-1,num_examples_per_fig))./examples_num_cols) + 1;
            col = mod(i-1,examples_num_cols)+1;
            subplot2(examples_num_rows+1,examples_num_cols,row+1,col);

            fi = miss_list_fi(i);
            ii = miss_list_ii(i);
            cur_im_fname = fnames_test_images{ mi, fi, ii };
            cur_workspace = workspaces_final{  mi, fi, ii };
            cur_p_struct = p_conditions{ mi,fi, ii };
            situate_draw_workspace( cur_im_fname, cur_p_struct, cur_workspace );

        end

        display( unique_descriptions{mi} );
        display( {fnames_test_images{failed_completions_logical_index}}' )

    end




    