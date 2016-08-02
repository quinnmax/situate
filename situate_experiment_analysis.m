

function situate_experiment_analysis( results_directory )


show_failures = true;


while ~exist( 'results_directory', 'var' ) || isempty(results_directory) || ~isdir(results_directory)

    h = msgbox('Select directory containing the results to analyze');
    uiwait(h);
    results_directory = uigetdir(pwd);     
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
    scouting_records_temp = {};
    workspaces_final_temp = {};  
    fnames_test_images_temp = {};
    run_data_temp = {};
    
    for fi = 1:length(fn);
        temp_d = load(fn{fi});
        for j = 1:length(temp_d.p_conditions)
            run_data_temp{end+1} = temp_d.run_data(j,:);
            p_conditions_temp{end+1} = temp_d.p_conditions(j);
            p_conditions_descriptions_temp{end+1} = temp_d.p_conditions_descriptions{j};
            scouting_records_temp{end+1} = temp_d.scouting_records(j,:);
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
    
    
    
    % go from files for folds to indexing
    % basically just get everything stored into method,fold,image indexing
    
    fnames_test_images         = cell(num_methods, num_folds, num_images_per_fold );
    workspaces_final           = cell(num_methods, num_folds, num_images_per_fold );
    scouting_records           = cell(num_methods, num_folds, num_images_per_fold );
    p_conditions_descriptions  = cell(num_methods, num_folds, num_images_per_fold );
    p_conditions               = cell(num_methods, num_folds, num_images_per_fold );
    
    for mi = 1:num_methods
        cur_method_linear_inds_list = find(strcmp( p_conditions_descriptions_temp, unique_descriptions{mi} ));
        cur_num_folds = length(cur_method_linear_inds_list);
    for fi = 1:cur_num_folds
        cur_fold_ind = cur_method_linear_inds_list(fi);
        cur_num_images_in_fold = length(scouting_records_temp{cur_fold_ind});
    for ii = 1:cur_num_images_in_fold
        
        fnames_test_images{mi,fi,ii}         = fnames_test_images_temp{           cur_fold_ind }{ii};
        workspaces_final{mi,fi,ii}           = workspaces_final_temp{             cur_fold_ind }{ii};
        scouting_records{mi,fi,ii}           = scouting_records_temp{             cur_fold_ind }{ii};
        p_conditions_descriptions{mi,fi,ii}  = p_conditions_descriptions_temp{    cur_fold_ind };
        p_conditions{mi,fi,ii}               = p_conditions_temp{                 cur_fold_ind };
        
    end
    end
    end
    
%% gather some interesting facts
    
    % check for successful detections against Ground Truth IOU
    
    iou_threshold = .5;
    successful_completion = false( num_methods, num_folds, num_images_per_fold );
    for mi = 1:size(workspaces_final,1)
    for fi = 1:size(workspaces_final,2)
    for ii = 1:size(workspaces_final,3)
        if isequal( sort(workspaces_final{mi,fi,ii}.labels), sort(p_conditions{mi,fi,ii}.situation_objects) )...
        && all(workspaces_final{mi,fi,ii}.GT_IOU >= iou_threshold)
            successful_completion(mi,fi,ii) = true;
        end
    end
    end
    end
    
    % gather data on detection order of objects
    
    detection_order_times  = inf(  num_methods, num_folds, num_images_per_fold, length(p_conditions{1,1,1}.situation_objects) );
    detection_order_labels = cell( num_methods, num_folds, num_images_per_fold, length(p_conditions{1,1,1}.situation_objects) );
    for mi = 1:size(scouting_records,1)
    for fi = 1:size(scouting_records,2)
    for ii = 1:size(scouting_records,3)
        temp_detection_times = inf(1,length(p_conditions{1,1,1}.situation_objects));
        situation_objects = p_conditions{mi,fi,ii}.situation_objects;
        for oi = 1:length(situation_objects)
            object_label = p_conditions{1,1,1}.situation_objects{oi};
            workspace_entry_event_inds_object_type    = strcmp(object_label,  scouting_records{mi,fi,ii}(:,2) );
            workspace_entry_event_inds_over_threshold = ge( round(100*[scouting_records{mi,fi,ii}{:,5}])/100, iou_threshold );
            a = reshape(workspace_entry_event_inds_object_type,1,[]);
            b = reshape(workspace_entry_event_inds_over_threshold,1,[]);
            c = and(a,b);
            cur_obj_first_detection_ind = find(c,1,'first');
            if ~isempty(cur_obj_first_detection_ind)
                temp_detection_times(oi) = scouting_records{mi,fi,ii}{cur_obj_first_detection_ind,1};
            end
        end
        [~,sort_order] = sort(temp_detection_times,'ascend');
        detection_order_times(mi,fi,ii,:) = temp_detection_times(sort_order);
        detection_order_labels(mi,fi,ii,:) = situation_objects(sort_order);
    end
    end
    end
        
    % reshape for detections as a function of number of proposals
    
    max_proposals = max(cellfun( @(x) x.num_iterations, p_conditions_temp));
    detections_at_num_proposals = zeros( num_methods, num_folds, max_proposals );    
    for mi = 1:num_methods
    for fi = 1:num_folds
    for ii = 1:num_images_per_fold
        cur_detection = detection_order_times(mi,fi,ii,end);
        if ~isinf(cur_detection) && successful_completion(mi,fi,ii)
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
    
    detections_at_num_proposals_total = squeeze( sum(detections_at_num_proposals,2) );

%% define methods to include, set their order, and define the line and color specifications

    %include_methods = find([1 1 0, 0 0 1, 0 0 0, 1 1 1, 1]);
    include_methods = find(true(1,length(unique_descriptions)));

    % define color space
    %colors = cool(length(include_methods));
    colors = color_fade([1 0 1; 0 0 0; 0 .75 0], length(include_methods ) );
    colors = sqrt(colors);

    linespec = {'-','--','-.'};
    linespec = repmat(linespec,1,ceil(length(include_methods)/length(linespec)));

    [~,sort_order] = sort(sum(detections_at_num_proposals_total(:,1:min(proposals_display_limit,size(detections_at_num_proposals_total,2))),2), 'descend');

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
    
    for i = 1:length(display_order);
        mi = display_order(i);
        plot( detections_at_num_proposals_total(mi,:), 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
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
    h_temp.FontSize = 8;
    try % works in matlab2016a, not 2015 versions apparently
        h_temp.Title.String = title_string;
    end
    
    h2.Position = [440 537 560 220];
    print(h2,fullfile(results_directory,'situate_experiment_figure'),'-r300', '-dpdf' );
     
    
    
%% medians over methods

    clear temp_a temp_b temp_c
    fprintf('Median time to first detection\n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(detection_order_times(mi,:,:,1),1,[]);
        temp_b = prctile(temp_a,50);
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(detection_order_times(mi,:,:,2),1,[]);
        temp_b = prctile( temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
%     clear temp_a temp_b temp_c
%     fprintf('Median time to third detection \n')
%     fprintf('  location: box shape; conditioning \n');
%     for mi = display_order
%         temp_a = reshape(detection_order_times(mi,:,:,3),1,[]);
%         temp_b = prctile( temp_a, 50 );
%         fprintf( '  %-50s  ', unique_descriptions{mi} );
%         fprintf( '%*.1f\n',10, temp_b );
%     end
%     fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time from first to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = reshape(detection_order_times(mi,:,:,1),1,[]);
        temp_b = reshape(detection_order_times(mi,:,:,2),1,[]);
        temp_c = prctile( temp_b - temp_a, 50 );
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*.1f\n',10, temp_c );
    end
    fprintf('\n\n');
    
%     clear temp_a temp_b temp_c
%     fprintf('Median time from second to third detection \n')
%     fprintf('  location: box shape; conditioning \n');
%     for mi = display_order
%         temp_a = reshape(detection_order_times(mi,:,:,2),1,[]);
%         temp_b = reshape(detection_order_times(mi,:,:,3),1,[]);
%         temp_c = prctile( temp_b - temp_a, 50 );
%         fprintf( '  %-50s  ', unique_descriptions{mi} );
%         fprintf( '%*.1f\n',10, temp_c );
%     end
%     fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Number of failed detections \n')
    fprintf('  location: box shape; conditioning \n');
    for mi = display_order
        temp_a = sum( reshape(successful_completion(mi,:,:),1,[]) );
        temp_b = numel( successful_completion(mi,:,:) );
        temp_c = temp_b - temp_a;
        fprintf( '  %-50s  ', unique_descriptions{mi} );
        fprintf( '%*d\n',10, temp_c );
    end
    fprintf('\n\n');
 
    
    
%% report on failed detections

    p = p_conditions{1,1,1};

    completion_iteration    = inf( size(scouting_records));
    final_workspace_snippet = cell(size(scouting_records));
    ending_support = cell(1,size(scouting_records,1));
    for mi = 1:size(scouting_records,1) % method
    for fi = 1:size(scouting_records,2) % fold
    for ii = 1:size(scouting_records,3) % image
        [completion_iteration(mi,fi,ii), ...
         final_workspace_snippet{mi,fi,ii}] = ...
            situate_workspace_entry_event_log_to_completion_time( ...
                scouting_records{mi,fi,ii}, ...
                p, 1000 );
    end
    end
        ending_support{mi} = cell2mat(final_workspace_snippet(mi,:)');
    end



%% draw the figures
% 
if show_failures
    for mi = 1:num_methods
    % for mi = find(strcmp(unique_descriptions,'salience, learned, yes'));

        failed_completions_logical_index = squeeze(   gt( completion_iteration(mi,:,:),  proposals_display_limit   ) );
        failed_completions      = sum( failed_completions_logical_index(:));
        [failed_i, failed_j] = find(failed_completions_logical_index);

        failures_count = [];
        zero_iou_counts = [];
        provisional_only_counts = [];
        for oi = 1:length(p.situation_objects)
            zero_iou_counts.(p.situation_objects{oi})           = sum( eq(ending_support{mi}(:,oi), 0 ) );
            provisional_only_counts.(p.situation_objects{oi})   = sum( lt(ending_support{mi}(:,oi), p.thresholds.total_support_final) .* gt(ending_support{mi}(:,oi), 0 ) );
            failures_count.(p.situation_objects{oi})            = sum( lt(ending_support{mi}(:,oi), p.thresholds.total_support_final) );
        end
        
        examples_num_rows = 3;
        examples_num_cols = 5;
        [miss_list_ii,miss_list_fi] = find(failed_completions_logical_index);
        num_examples_per_fig = examples_num_rows * examples_num_cols;
        for i = 1:length(miss_list_fi)

            if mod(i,num_examples_per_fig) == 1
%                 figure;
%                 subplot2(examples_num_rows + 1,examples_num_cols, 1,1,1,examples_num_cols);
                h = draw_box([0 0 1 1],'xywh');
                t = {};
                t{1} = unique_descriptions{mi};
                t{2} = sprintf('number images not completed:  %*d', 3, failed_completions );

                for oi = 1:length(p.situation_objects)
                    t{2+oi} = sprintf('missed %s: %*d', p.situation_objects{oi}, 3, sum(lt(ending_support{mi}(:,oi),p.thresholds.total_support_final)) );
                end

                h_temp = text(.1,.5,t);
                h_temp.FontName = 'MonoSpaced';
                h.Parent.Visible = 'off';
            end


%             row = floor((mod(i-1,num_examples_per_fig))./examples_num_cols) + 1;
%             col = mod(i-1,examples_num_cols)+1;
%             subplot2(examples_num_rows+1,examples_num_cols,row+1,col);

            fi = miss_list_fi(i);
            ii = miss_list_ii(i);
            cur_im_fname = fnames_test_images{ mi, fi, ii };
            cur_workspace = workspaces_final{  mi, fi, ii };
            cur_p_struct = p_conditions{ mi,fi, ii };
            situate_draw_workspace( cur_im_fname, cur_p_struct, cur_workspace );

            
            waitforbuttonpress();
        end

        display( unique_descriptions{mi} );
        display( {fnames_test_images{failed_completions_logical_index}}' )

    end
end

end










function output = color_fade(colors, n )

    % output = color_fade( n );
    % output = color_fade(colors, n );
    %
    % with one arg, colors will be magenta to green

    
    if nargin < 2
        n = colors;
        colors = [];
        colors(1,:) = [1 0 1];
        colors(3,:) = [0 0 0];
        colors(4,:) = [0 1 0];
    end
    
    
    ns = round(linspace(1,n,size(colors,1)));
    
    
    
    output = [];
    for ci = 1:(size(colors,1)-1)
        
        cur_steps = ns(ci+1)-ns(ci) + 1;
        color_temp = [ ...
            linspace(colors(ci,1),colors(ci+1,1),cur_steps)', ...
            linspace(colors(ci,2),colors(ci+1,2),cur_steps)', ...
            linspace(colors(ci,3),colors(ci+1,3),cur_steps)'  ];
        output = [output; color_temp(1:end-1,:)];
        
    end 
    output = [output; colors(end,:)];
end




    