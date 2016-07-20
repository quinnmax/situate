all_iou = [];
all_ground_truth_boxes = {};
all_detected_boxes = {};

file_names = map(num2cell(dir('Rory*.mat')), @(x) x.name);

proposals_display_limit = 1000;


%% reshaping the data


% gather all p_conditions and p_conditions descriptions
p_conditions_temp = [];
p_conditions_descriptions_temp = {};
workspace_entry_event_logs_temp = {};
workspaces_final_temp = {};
fnames_test_images_temp = {};

for fi = 1:length(file_names);
    temp_d = load(file_names{fi});
    for j = 1:length(temp_d.p_conditions)
        p_conditions_temp{end+1} = temp_d.p_conditions(j);
        p_conditions_descriptions_temp{end+1} = temp_d.p_conditions_descriptions{j};
        workspace_entry_event_logs_temp{end+1} = temp_d.workspace_entry_event_logs(j,:);
        workspaces_final_temp{end+1} = {temp_d.workspaces_final{j,:}};
        fnames_test_images_temp{end+1} = temp_d.fnames_im_test;
    end
end

[unique_descriptions, ~, group_assignment_inds] = unique( p_conditions_descriptions_temp );
num_methods = length(unique_descriptions);

description_counts = counts(p_conditions_descriptions_temp);
if ~all(eq(description_counts(1), description_counts)), warning('different numbers of runs for different experimental conditions'); end
num_folds = max(description_counts);

images_per_run = cellfun( @length, workspaces_final_temp );
if ~all(eq(images_per_run(1),images_per_run)), warning('different numbers of images in different runs'); end
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
            
            
            %Check if it's a valid detection
            label_file = strrep(fnames_test_images{mi,fi,ii}, '.jpg', '.labl');
            %label_file = strrep(label_file, '/home/rsoiffer', 'C:/Users/Rory');
            label = situate_image_data_label_adjust(situate_image_data(label_file), p_conditions{mi,fi,ii});
            %label = situate_image_data_rescale(label, sqrt(p_conditions{mi,fi,ii}.image_redim_px / (0.0 + label.im_w * label.im_h)));
            for obj = 1:numel(workspaces_final{mi,fi,ii}.labels)
                obj_type = workspaces_final{mi,fi,ii}.labels(obj);
                ground_truth_id = find(strcmp(label.labels_adjusted, obj_type), 1);
                ground_truth_box_xywh = label.boxes_xywh(ground_truth_id, :) * sqrt(p_conditions{mi,fi,ii}.image_redim_px / (0.0 + label.im_w * label.im_h));
                detection_box_r0rfc0cf = workspaces_final{mi,fi,ii}.boxes(obj, :);
                detection_box_c0r0cfrf = detection_box_r0rfc0cf([3, 1, 4, 2]);
                detection_box_xywh = [detection_box_c0r0cfrf(1), detection_box_c0r0cfrf(2), detection_box_c0r0cfrf(3) - detection_box_c0r0cfrf(1), detection_box_c0r0cfrf(4) - detection_box_c0r0cfrf(2)];
                iou = intersection_over_union_xywh(ground_truth_box_xywh, detection_box_xywh);
                relevant_detections = strcmp(workspace_entry_event_logs{mi,fi,ii}(:,2), obj_type);
                was_over_threshold(relevant_detections) = and(was_over_threshold(relevant_detections), iou > .25);
                
                all_iou(end+1) = iou;
                all_ground_truth_boxes{end+1} = ground_truth_box_xywh;
                all_detected_boxes{end+1} = detection_box_xywh;
%                 if rand() < .1
%                     display(detection_box_xywh);
%                     display(ground_truth_box_xywh);
%                 end
            end
            
            % if a box is improved, just keep the time for the first
            % acceptable detection so we're just looking for the first
            % detections of each object type (that's over the detection
            % threshold)
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



% use min for time to first detections, median for time to second
% detection, and max for time to third detection
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
                
                % check if the detection was actually correct
                
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


%% modify for pretty display descriptions.
% make sure the order matches display( unique_descriptions' );

display_descriptions = {};
space1 = 16;
space2 = 11;
space3 = 5;

title_string = sprintf( '%-*s %-*s %-*s %s', space1, 'Location Prior', space2, 'Box Prior', space3,  'Situation Model', repmat(char(160),1,1) );

display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Learned', space3, 'Learned' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Learned', space3, 'Learned (No Provisional)' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Uniform', space3, 'Learned' );

display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Learned', space3, 'None' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Learned', space3, 'Learned' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Salience', space2, 'Uniform', space3, 'None' );

display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Learned', space3, 'None' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Uniform', space3, 'None' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Uniform', space3, 'Learned' );

display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Learned', space3, 'None' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Learned', space3, 'Learned' );
display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'Uniform',  space2, 'Uniform', space3, 'None' );

display_descriptions{end+1} = sprintf( '%-*s %-*s %-*s', space1, 'RP',       space2, 'RP',      space3, 'None' );
display(display_descriptions');


%% define methods to include and order

include_methods = find([1 1 0, 0 0 1, 0 0 0, 1 1 1, 1]);

% assign colors to methods
colors = color_fade([1 0 1; 0 0 0; 0 .75 0], length(include_methods ) );
colors = sqrt(colors);

linespec = {'-','--','-.','-','--','-.','-'};
linespec = repmat(linespec,1,5);

detections_at_num_proposals_squeezed = squeeze(sum(detections_at_num_proposals,  2));
[~,sort_order] = sort(sum(detections_at_num_proposals_squeezed(:,1:proposals_display_limit),2), 'descend');

display_order = [];
for mi = 1:length(sort_order)
    if ismember( sort_order(mi), include_methods)
        display_order = [display_order sort_order(mi)];
    end
end

rp_ind = find(strcmp(unique_descriptions,'randomized prims'));
display_order_no_prims = display_order;
% display_order_no_prims( find( eq( display_order_no_prims, rp_ind ) ) ) =
% [];



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
h_temp = legend(display_descriptions(display_order),'Location','eastoutside','FontName','FixedWidth');
%h_temp.Title.String = title_string;
h_temp.FontSize = 8;

h2.Position = [440 537 560 220];
print(h2,'situate_experiment_figure_2','-r300', '-dpdf' )



%% medians over methods

detections_at_num_proposals_squeezed = squeeze(sum(detections_at_num_proposals,  2));

clear temp_a temp_b temp_c
fprintf('Median time to first detection\n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order_no_prims
    temp_a = reshape(first_detections(mi,:,:),1,[]);
    temp_b = prctile(temp_a,50);
    fprintf( '  %-50s  ', display_descriptions{mi} );
    fprintf( '%*.1f\n',10, temp_b );
end
fprintf('\n\n');

clear temp_a temp_b temp_c
fprintf('Median time to second detection \n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order_no_prims
    temp_a = reshape(second_detections(mi,:,:),1,[]);
    temp_b = prctile( temp_a, 50 );
    fprintf( '  %-50s  ', display_descriptions{mi} );
    fprintf( '%*.1f\n',10, temp_b );
end
fprintf('\n\n');

clear temp_a temp_b temp_c
fprintf('Median time to third detection \n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order
    temp_a = reshape(third_detections(mi,:,:),1,[]);
    temp_b = prctile( temp_a, 50 );
    fprintf( '  %-50s  ', display_descriptions{mi} );
    fprintf( '%*.1f\n',10, temp_b );
end
fprintf('\n\n');

clear temp_a temp_b temp_c
fprintf('Median time from first to second detection \n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order_no_prims
    temp_a = reshape(first_detections(mi,:,:),1,[]);
    temp_b = reshape(second_detections(mi,:,:),1,[]);
    miss_list_c = prctile( temp_b - temp_a, 50 );
    fprintf( '  %-50s  ', display_descriptions{mi} );
    fprintf( '%*.1f\n',10, miss_list_c );
end
fprintf('\n\n');

clear temp_a temp_b temp_c
fprintf('Median time from second to third detection \n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order_no_prims
    temp_a = reshape(second_detections(mi,:,:),1,[]);
    temp_b = reshape(third_detections(mi,:,:),1,[]);
    miss_list_c = prctile( temp_b - temp_a, 50 );
    fprintf( '  %-50s  ', display_descriptions{mi} );
    fprintf( '%*.1f\n',10, miss_list_c );
end
fprintf('\n\n');

clear temp_a temp_b temp_c
fprintf('Number of failed detections \n')
fprintf('  location: box shape; conditioning \n');
for mi = display_order
    temp_a = reshape(third_detections(mi,:,:),1,[]);
    temp_b = sum( gt(temp_a,proposals_display_limit) );
    fprintf( '  %-50s  ', display_descriptions{mi} );
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

for mi = 1:num_methods
%for mi = find(strcmp(unique_descriptions,'salience, learned, yes'));
    
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
%             figure;
%             subplot2(examples_num_rows + 1,examples_num_cols, 1,1,1,examples_num_cols);
            h = draw_box_xywh([0 0 1 1]);
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
        
        
%         row = floor((mod(i-1,num_examples_per_fig))./examples_num_cols) + 1;
%         col = mod(i-1,examples_num_cols)+1;
%         subplot2(examples_num_rows+1,examples_num_cols,row+1,col);
        
        fi = miss_list_fi(i);
        ii = miss_list_ii(i);
        cur_im_fname = fnames_test_images{ mi, fi, ii };
        cur_workspace = workspaces_final{  mi, fi, ii };
        cur_p_struct = p_conditions{ mi,fi, ii };
        situate_draw_workspace( cur_im_fname, cur_p_struct, cur_workspace );
        
        
        ginput();
    end
    
    display( unique_descriptions{mi} );
    display( {fnames_test_images{failed_completions_logical_index}}' )
    
end
