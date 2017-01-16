


function situate_experiment_analysis( results_directory, show_failure_examples )
% situate_experiment_analysis( results_directory, show_failure_examples );



%% set data source 

    if ~exist('show_failure_examples','var') || isempty(show_failure_examples)
        show_failure_examples = true;
    end

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


%% reshaping the data 
    
    % gather all p_conditions and p_conditions descriptions
    p_conditions_temp = [];
    p_conditions_descriptions_temp = {};
    agent_records_temp = {};
    workspaces_final_temp = {};  
    fnames_test_images = {};
    % run_data_temp = {};
    
    for fi = 1:length(fn) % file ind
        temp_d = load(fn{fi});
        p_conditions_temp{end+1} = temp_d.p_condition;
        p_conditions_descriptions_temp{fi} = temp_d.p_condition_description;
        agent_records_temp{end+1} = temp_d.agent_records;
        workspaces_final_temp{end+1} = temp_d.workspaces_final;
        fnames_test_images{end+1} = temp_d.fnames_im_test;
    end
    clear temp_d;
    
    [description_counts, p_conditions_descriptions] = counts( p_conditions_descriptions_temp );
    num_conditions = length(p_conditions_descriptions);
    
    % check that things seem balanced
    if ~all(eq(description_counts(1), description_counts)), error('different numbers of runs for different experimental conditions'); end
    images_per_run = cellfun( @length, workspaces_final_temp );
    if ~all(eq(images_per_run(1),images_per_run)), error('different numbers of images in different runs'); end
    
    num_images = sum( cellfun( @length, workspaces_final_temp ) ) / length(p_conditions_descriptions);
    
%% group on condition
    
    workspaces_final           = cell(num_conditions, num_images);
    agent_records              = cell(num_conditions, num_images);
    p_conditions               = cell(num_conditions,1);
    
    for ci = 1:num_conditions
        cur_condition_inds = strcmp( p_conditions_descriptions{ci}, p_conditions_descriptions_temp );
        p_conditions(ci) = p_conditions_temp(find(cur_condition_inds,1,'first'));
        workspaces_final(ci,:)  = [workspaces_final_temp{cur_condition_inds}];
        agent_records(ci,:)     = [agent_records_temp{cur_condition_inds}];
    end

    clear agent_records_temp;
    

    
%% check for successful detections against Ground Truth IOU
    
    iou_threshold = .5;
    successful_completion = false( num_conditions, num_images );
    for ci = 1:num_conditions
    for ii = 1:num_images
        if isequal( sort(workspaces_final{ci,ii}.labels), sort(p_conditions{ci}.situation_objects) )...
        && all(workspaces_final{ci,ii}.GT_IOU >= iou_threshold)
            successful_completion(ci,ii) = true;
        end
    end
    end
    
    
    
%% gather data on detection order of objects
    
    detection_order_times  = inf(  num_conditions, num_images, length(p_conditions{1}.situation_objects) );
    detection_order_labels = cell( num_conditions, num_images, length(p_conditions{1}.situation_objects) );
    for ci = 1:num_conditions
    for ii = 1:num_images
        situation_objects = p_conditions{ci}.situation_objects;
        temp_detection_times = inf(1,length(situation_objects));
        cur_support_record = [agent_records{ci,ii}.support];
        %for i = 1:length(cur_support_record), if isempty(cur_support_record(i).total), cur_support_record(i).total = 0; end; end % this should already be true, but there was a situation where it wasn't initialized properly. fixed now
        for oi = 1:length(situation_objects)
            object_label = situation_objects{oi};
            workspace_entry_event_inds_object_type = strcmp(object_label,  {agent_records{ci,ii}.interest} );
            workspace_entry_event_inds_over_threshold = ge( round(100*[cur_support_record.total])/100, iou_threshold );
            a = reshape(workspace_entry_event_inds_object_type,1,[]);
            b = reshape(workspace_entry_event_inds_over_threshold,1,[]);
            c = and(a,b);
            cur_obj_first_detection_ind = find(c,1,'first');
            if ~isempty(cur_obj_first_detection_ind) 
                temp_detection_times(oi) = cur_obj_first_detection_ind;
            end
        end
        [~,sort_order] = sort(temp_detection_times,'ascend');
        detection_order_times(ci,ii,:)  = temp_detection_times(sort_order);
        detection_order_labels(ci,ii,:) = situation_objects(sort_order);
    end
    end
    
    
    
    % reshape for detections as a function of number of proposals
    
    max_proposals = max(cellfun( @(x) x.num_iterations, p_conditions_temp));
    detections_at_num_proposals = zeros( num_conditions, max_proposals );    
    for ci = 1:num_conditions
    for ii = 1:num_images
        cur_detection = detection_order_times(ci,ii,end);
        if ~isinf(cur_detection) && successful_completion(ci,ii)
            detections_at_num_proposals(ci,cur_detection:end) = detections_at_num_proposals(ci,cur_detection:end) + 1;
        end
    end
    end
    


%% define conditions to include, color and line specifications 

    proposals_display_limit = max_proposals;
    % proposals_display_limit = 1000;

    include_conditions = find(true(1,length(p_conditions_descriptions)));
    %include_conditions = find([1 1 0, 0 0 1, 0 0 0, 1 1 1, 1]);
    
    % define color space
    % colors = cool(length(include_conditions));
    % colors = color_fade([1 0 1; 0 0 0; 0 .75 0], length(include_conditions ) );
    colors = zeros( 5,3);
    colors = sqrt(colors);

    linespec = {'-','--','-.',':'};
    linespec = repmat(linespec,1,ceil(length(include_conditions)/length(linespec)));

    [~,sort_order] = sort(sum(detections_at_num_proposals(:,1:min(proposals_display_limit,size(detections_at_num_proposals,2))),2), 'descend');

    display_order = [];
    for ci = 1:length(sort_order)
        if ismember( sort_order(ci), include_conditions)
            display_order = [display_order sort_order(ci)];
        end
    end



%% figure: completed detections as a function of iterations 

    h2 = figure();
    h2.Color = [1 1 1];
    hold on;
    
    for i = 1:length(display_order);
        ci = display_order(i);
        %plot( detections_at_num_proposals_total(ci,:), 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
        plot( detections_at_num_proposals(ci,:), 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
    end
    hold off;
    
    hold on;
        plot([0 max_proposals], [num_images, num_images], '--black')
    hold off;
    
    box(h2.CurrentAxes,'on');
    
    xlabel(  'Iterations' );
    ylabel({ 'Completed Situation Detections', '(Cumulative)' });
 
    xlim([0 max_proposals]);
    xlim([0 proposals_display_limit])  
    ylim([0 1.1*num_images]);
    
    % legend(unique_descriptions(sort_order),'Location','Northeast');
    title_string = 'Situation recognition method';
    h_temp = legend(p_conditions_descriptions(display_order),'Location','eastoutside','FontName','FixedWidth');
    h_temp.FontSize = 8;
    try % works in matlab2016a, not 2015 versions apparently
        h_temp.Title.String = title_string;
    end
    
    h2.Position = [440 537 560 220];
    print(h2,fullfile(results_directory,'situate_experiment_figure'),'-r300', '-dpdf' );



%% table: medians over conditions 

    clear temp_a temp_b temp_c
    fprintf('Median time to first detection\n')
    fprintf('  location: box shape; conditioning \n');
    for ci = display_order
        temp_a = reshape(detection_order_times(ci,:,1),1,[]);
        temp_b = prctile(temp_a,50);
        fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    clear temp_a temp_b temp_c
    fprintf('Median time to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for ci = display_order
        temp_a = reshape(detection_order_times(ci,:,2),1,[]);
        temp_b = prctile( temp_a, 50 );
        fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
        fprintf( '%*.1f\n',10, temp_b );
    end
    fprintf('\n\n');
    
    if size( detection_order_times, 4 ) >= 3
        clear temp_a temp_b temp_c
        fprintf('Median time to third detection \n')
        fprintf('  location: box shape; conditioning \n');
        for mi = display_order
            temp_a = reshape(detection_order_times(mi,:,3),1,[]);
            temp_b = prctile( temp_a, 50 );
            fprintf( '  %-50s  ', p_conditions_descriptions{mi} );
            fprintf( '%*.1f\n',10, temp_b );
        end
        fprintf('\n\n');
    end
    
    clear temp_a temp_b temp_c
    fprintf('Median time from first to second detection \n')
    fprintf('  location: box shape; conditioning \n');
    for ci = display_order
        temp_a = reshape(detection_order_times(ci,:,1),1,[]);
        temp_b = reshape(detection_order_times(ci,:,2),1,[]);
        rem_NaNs = temp_b - temp_a;
        rem_NaNs(isnan(rem_NaNs)) = inf;
        temp_c = prctile( rem_NaNs, 50 );
        fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
        fprintf( '%*.1f\n',10, temp_c );
    end
    fprintf('\n\n');
    
    if size( detection_order_times, 4 ) >= 3
        clear temp_a temp_b temp_c
        fprintf('Median time from second to third detection \n')
        fprintf('  location: box shape; conditioning \n');
        for mi = display_order
            temp_a = reshape(detection_order_times(mi,:,2),1,[]);
            temp_b = reshape(detection_order_times(mi,:,3),1,[]);
            rem_NaNs = temp_b - temp_a;
            rem_NaNs(isnan(rem_NaNs)) = inf;
            temp_c = prctile( temp_b - temp_a, 50 );
            fprintf( '  %-50s  ', p_conditions_descriptions{mi} );
            fprintf( '%*.1f\n',10, temp_c );
        end
        fprintf('\n\n');
    end
    
    clear temp_a temp_b temp_c
    fprintf('Number of failed detections \n')
    fprintf('  location: box shape; conditioning \n');
    for ci = display_order
        temp_a = sum( reshape(successful_completion(ci,:),1,[]) );
        temp_b = numel( successful_completion(ci,:) );
        temp_c = temp_b - temp_a;
        fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
        fprintf( '%*d\n',10, temp_c );
    end
    fprintf('\n\n');



%% report: failed detections, final workspace 

    if show_failure_examples
        
        num_rows = 2;
        num_cols = 3;
        
        for ci = 1:size(successful_completion,1)
            figure();
            cur_display_counter = 1;
            for ii = 1:size(successful_completion,2)
                if ~successful_completion(ci,ii)
                    subplot(num_rows,num_cols,cur_display_counter);
                    situate_draw_workspace(fnames_test_images{ci}{ii},p_conditions{ci},workspaces_final{ci,ii} );
                    if cur_display_counter == 1
                        title(p_conditions{ci}.description);
                    end
                    cur_display_counter = cur_display_counter + 1;
                    if mod(cur_display_counter,num_rows*num_cols) == 1
                        %figure();
                        %cur_display_counter = 1;
                        break;
                    end   
                end
            end
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


