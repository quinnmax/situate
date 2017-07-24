


function situate_experiment_analysis( results_directory, show_failure_examples )
% situate_experiment_analysis( results_directory, show_failure_examples );





%% data source 

    if ~exist('show_failure_examples','var') || isempty(show_failure_examples)
        show_failure_examples = false;
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


%% group on condition
   
    % just get the description for grouping
    p_conditions_temp = cell(1,length(fn));
    p_conditions_descriptions_temp = cell(1,length(fn));
    for fi = 1:length(fn) % file ind
        temp = load(fn{fi},'p_condition');
        p_conditions_temp{fi} = temp.p_condition;
        p_conditions_descriptions_temp{fi} = temp.p_condition.description;
        progress(fi,length(fn),'loading parameterization data');
    end
    
    [p_conditions_descriptions,~,condition_indices] = unique(p_conditions_descriptions_temp);
    num_conditions = length(p_conditions_descriptions);
    
    results_per_condition = [];
    
%% reshape the data

    %   load up related files, combine
    for ci = 1:num_conditions
    %for ci = 5
        cur_files_inds = find(eq(ci,condition_indices));
        temp_data = cell(1,length(cur_files_inds));
        for fii = 1:length(cur_files_inds)
            fi = cur_files_inds(fii);
            cur_fname = fn{fi};
            fprintf('condition: %i trial: %i fname: %s \n', ci,fii,cur_fname);
            temp_data{fii} = load(cur_fname);
        end
        
        p_condition = temp_data{1}.p_condition;
        
        workspaces_final = cellfun( @(x) x.workspaces_final, temp_data, 'UniformOutput', false);
        workspaces_final = cellfun( @(x) [x{:}], workspaces_final, 'UniformOutput', false);
        workspaces_final = [workspaces_final{:}];
        
        agent_records = cellfun( @(x) x.agent_records, temp_data, 'UniformOutput', false);
        agent_records = cellfun( @(x) [x{:}], agent_records, 'UniformOutput', false);
        agent_records = [agent_records{:}]';
        
        fnames_test = cellfun( @(x) x.fnames_im_test, temp_data, 'UniformOutput', false);
        fnames_test = cellfun( @(x) x', fnames_test,'UniformOutput',false);
        fnames_test = [fnames_test{:}]';
        
        results_per_condition(ci).condition = p_condition.description;
        
        
        
        % detections at threshold, iteration
        num_thresholds = 11;
        iou_thresholds = sort(unique([linspace(0,1,num_thresholds) .5])); % make sure .5 is in there
        num_thresholds = length(iou_thresholds);
        num_images = length(fnames_test);
        situation_objects = p_condition.situation_objects;
        num_situation_objects = length(situation_objects );
        
        % final IOUs for objects
        final_ious = zeros( num_images, num_situation_objects );
        for imi = 1:num_images
        for oi  = 1:num_situation_objects
            wi  = strcmp( situation_objects{oi},workspaces_final(imi).labels);
            if any(wi)
                final_ious(imi,oi) = workspaces_final(imi).GT_IOU(wi);
            end
        end
        end
        results_per_condition(ci).iou_thresholds = iou_thresholds;
        results_per_condition(ci).final_ious = final_ious;
        results_per_condition(ci).final_ious_desc = 'image index, iou per object in situation_objects ordering';
        
        
        
        % detections at various IOU thresholds
        detections_at_iou = zeros( num_thresholds, num_situation_objects+1 );
        for ti  = 1:num_thresholds
            for oi  = 1:num_situation_objects
                detections_at_iou(ti,oi) = sum( ge( final_ious(:,oi), iou_thresholds(ti) ) );
            end
            detections_at_iou(ti,end) = sum( all( final_ious >= iou_thresholds(ti), 2 ) );
        end
        results_per_condition(ci).detections_at_iou = detections_at_iou;
        results_per_condition(ci).detections_at_iou_desc = {'iou threshold ind, situation object ind';'end + 1 for full situation'};
        
        
        
        % time of first detections (over GT IOU threshold )
        first_iteration_over_threshold = zeros( num_images, num_situation_objects+1, num_thresholds );

        for ii = 1:num_images
        for ti = 1:num_thresholds
            
            for oi = 1:num_situation_objects

                iterations_of_interest = find([agent_records(ii,:).interest] == oi);
                temp             = [agent_records(ii,:).support];
                temp             = temp(iterations_of_interest);
                internal_support = [temp.internal];
                total_support    = [temp.total];
                gt_iou           = [temp.GROUND_TRUTH];

                % first with an actual gt_iou over threshold 
                % and total support over threshold (using .5 total support)
                % first_over_threshold = find( ge( gt_iou, iou_thresholds(ti) ), 1, 'first' );
                first_over_threshold = find( ge( gt_iou, iou_thresholds(ti) ) & ge( total_support, iou_thresholds(ti) ), 1, 'first' );

                if ~isempty(first_over_threshold)
                    first_iteration_over_threshold(ii,oi,ti) = iterations_of_interest( first_over_threshold );
                else
                    first_iteration_over_threshold(ii,oi,ti) = nan;
                end
            
            end
            
            
        
            if any(isnan(first_iteration_over_threshold(ii,1:num_situation_objects,ti)))
                first_iteration_over_threshold(ii,end,ti) = nan;
            else
                first_iteration_over_threshold(ii,end,ti) = max(first_iteration_over_threshold(ii,1:num_situation_objects,ti));
            end
        
        end
            fprintf('.');
            if mod(ii,100)==0, fprintf('\n'); end
        end
        fprintf('\n');
        results_per_condition(ci).first_iteration_over_threshold = first_iteration_over_threshold;
        results_per_condition(ci).first_iteration_over_threshold_desc = {'image index, object index, iou threshold index';'checks for total support over threshold AND gt iou over threshold'};
        
        
        
        % record how many scouts were looking for each object type during the run
        
        % show what scouts were looking for during the run (with final IOU info in the title)
        figure('Name',['scout trace: ' p_conditions_descriptions{ci}]);
        num_subplots = min(25,num_images);
        for imi = 1:num_subplots
            subplot_lazy(num_subplots,imi);
            agent_interests = double([agent_records(imi,:).interest]);
            plot(agent_interests + .1*randn(size(agent_interests)),'.');
            yticks(0:3);
            yticklabels(['none' situation_objects]);
            ylim([-.5 3.5])
            if imi == 1, ylabel('agent interest'); xlabel('iteration'); end  
            
            gt_ious = zeros(1,num_situation_objects);
            for oi = 1:num_situation_objects
                wi = find(strcmp( workspaces_final(imi).labels, situation_objects{oi}));
                if ~isempty(wi) 
                    gt_ious(oi) = workspaces_final(imi).GT_IOU(wi); 
                else
                    gt_ious(oi) = 0; 
                end
            end
            
            title_string = [sprintf('%10s ',situation_objects{:}) sprintf('\n') sprintf('%10.3f ', gt_ious )];
            title(title_string);
        end
        
        
        
        % cumulative detections as function of proposals
        detections_at_num_proposals = zeros( num_thresholds, num_situation_objects + 1, p_condition.num_iterations );
        for imi = 1:num_images
        for ti  = 1:num_thresholds
        for oi  = 1:num_situation_objects + 1
            cur_detection_ind = first_iteration_over_threshold(imi,oi,ti);
            % add to detections if it's a specific object that was detected
            % OR if it was the last object to be checked in over threshold for a situation that was
            % still checked in by the end. Edge case we're avoiding: all three objects were checked in at
            % some point (maybe not at the same time) but the situation was not correctly found in
            % the end. 
            do_add_to_detections = ~isnan(cur_detection_ind) ...
                && ( ~oi==num_situation_objects+1 || all(final_ious(imi,:)>=iou_thresholds(ti) ) );
            if do_add_to_detections
                detections_at_num_proposals( ti, oi, cur_detection_ind:end ) = ...
                detections_at_num_proposals( ti, oi, cur_detection_ind:end ) + 1;
            end
        end
        end
        fprintf('.'); if mod(imi,100)==0, fprintf('\n'); end
        end
        fprintf('\n');
        results_per_condition(ci).detections_at_num_proposals = detections_at_num_proposals;
        results_per_condition(ci).detections_at_num_proposals_desc = {'iou threshold index, object index, iteration';'how many of each object type were detected by iteration for threshold'};
        
            
        
    end
   
% stack them up over condition
    final_ious = [];
    detections_at_iou = [];
    first_iteration_over_threshold = [];
    detections_at_num_proposals = [];
    for ci = 1:num_conditions
        final_ious(ci,:,:) = results_per_condition(ci).final_ious;
            % condition, image, object
        detections_at_iou(ci,:,:) = results_per_condition(ci).detections_at_iou;
            % condition, threshold, object
        first_iteration_over_threshold(ci,:,:,:) = results_per_condition(ci).first_iteration_over_threshold;
            % condition, image, object, threshold
        detections_at_num_proposals(ci,:,:,:) = results_per_condition(ci).detections_at_num_proposals;
            % condition, threshold, object, iteration
    end
    
    %%
    
    clear temp_data;
    clear agent_records;
    clear temp;
    
    
    
%% gather data on detection order of objects
    
%     iou_threshold = .5;
%     detection_order_times  = inf(  num_conditions, num_images, length(p_conditions{1}.situation_objects) );
%     detection_order_labels = cell( num_conditions, num_images, length(p_conditions{1}.situation_objects) );
%     for ci = 1:num_conditions
%     for ii = 1:num_images
%         situation_objects = p_conditions{ci}.situation_objects;
%         temp_detection_times = inf(1,length(situation_objects));
%         cur_support_record = [agent_records{ci,ii}.support];
%         for oi = 1:length(situation_objects)
%             workspace_entry_event_inds_over_threshold = ge( round(100*[cur_support_record.total])/100, iou_threshold );
%             interest_records = [agent_records{ci,ii}.interest];
%             interest_records(length(workspace_entry_event_inds_over_threshold)+1:end) = [];
%             workspace_entry_event_inds_object_type = oi == interest_records;
%             
%             a = reshape(workspace_entry_event_inds_object_type,1,[]);
%             b = reshape(workspace_entry_event_inds_over_threshold,1,[]);
%             c = and(a,b);
%             cur_obj_first_detection_ind = find(c,1,'first');
%             if ~isempty(cur_obj_first_detection_ind) 
%                 temp_detection_times(oi) = cur_obj_first_detection_ind;
%             end
%         end
%         [~,sort_order] = sort(temp_detection_times,'ascend');
%         detection_order_times(ci,ii,:)  = temp_detection_times(sort_order);
%         detection_order_labels(ci,ii,:) = situation_objects(sort_order);
%     end
%     end
%     
%     % reshape for detections as a function of number of proposals
%     
%     
%     detections_at_num_proposals = zeros( num_conditions, p_condit );    
%     for ci = 1:num_conditions
%     for ii = 1:num_images
%         cur_detection = detection_order_times(ci,ii,end);
%         if ~isinf(cur_detection) && successful_completion(ci,ii)
%             detections_at_num_proposals(ci,cur_detection:end) = detections_at_num_proposals(ci,cur_detection:end) + 1;
%         end
%     end
%     end
%     
%     fprintf('.');
    

%% define conditions to include, color and line specifications 

    proposals_display_limit = p_condition.num_iterations;
    % proposals_display_limit = 1000;

    include_conditions = find(true(1,num_conditions));
    %include_conditions = find([1 1 0, 0 0 1, 0 0 0, 1 1 1, 1]);
    
    linespec = {'-','--','-.',':'};
    linespec = repmat(linespec,1,ceil(length(include_conditions)/length(linespec)));

    % figure out a display order that emphasizes completed situation detections
    iou_threshold_index = find(eq(min(abs(iou_thresholds-.5)),abs(iou_thresholds-.5)));
    full_situation_index = num_situation_objects + 1;
    [~,sort_order] = sort( detections_at_num_proposals(:,iou_threshold_index,full_situation_index,proposals_display_limit), 'descend' );
    
    display_order = [];
    for ci = 1:length(sort_order)
        if ismember( sort_order(ci), include_conditions)
            display_order = [display_order sort_order(ci)];
        end
    end
    
    % define color space
    % colors = cool(length(include_conditions));
    % colors = color_fade([1 0 1; 0 0 0; 0 .75 0], length(include_conditions ) );
    colors = zeros( length(include_conditions),3);
    colors = sqrt(colors);


    
    
    
%% figure: completed detections as a function of iterations 

    h2 = figure();
    h2.Color = [1 1 1];
    hold on;
    
    for i = 1:length(display_order)
        ci = display_order(i);
        cur_data = detections_at_num_proposals(ci,iou_threshold_index,num_situation_objects+1,:);
        cur_data = squeeze(cur_data);
        plot( cur_data, 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
        % condition, threshold, object, iteration
    end
    hold off;
    
    hold on;
        plot([0 proposals_display_limit], [num_images, num_images], '--blue')
    hold off;
    
    box(h2.CurrentAxes,'on');
    
    xlabel(  'Iterations' );
    ylabel({ 'Completed Situation Detections', '(Cumulative)' });
 
    xlim([0 proposals_display_limit]);
    ylim([0 1.1*num_images]);
    
    % legend(unique_descriptions(sort_order),'Location','Northeast');
    title_string = 'Situation recognition method';
    h_temp = legend(p_conditions_descriptions(display_order),'Location','eastoutside','FontName','FixedWidth');
    h_temp.FontSize = 8;
    try % works in matlab2016a, not 2015 versions apparently
        h_temp.Title.String = title_string;
    end
    
    h2.Position = [440 537 560 220];
    print(h2,fullfile(results_directory,'situate_experiment_figure'),'-r300', '-dpdf','-bestfit' );
    saveas(h2,fullfile(results_directory,'situate_experiment_figure detections at iteration'),'png');
    
    ylim([0, 1.1*max([1; max(reshape(detections_at_num_proposals(:,iou_threshold_index,num_situation_objects+1,:),1,[]))]) ]);
    ylabel({ 'Completed Situation Detections', ['(Cumulative, max: ' num2str(num_images) ')'] });
    print(h2,fullfile(results_directory,'situate_experiment_figure_zoomed'),'-r300', '-dpdf','-bestfit' );
    saveas(h2,fullfile(results_directory,'situate_experiment_figure detections at iteration zoomed'),'png');
    
    
    


%% table: medians over conditions 

%     clear temp_a temp_b temp_c
%     fprintf('Median time to first detection\n')
%     fprintf('  location: box shape; conditioning \n');
%     for ci = display_order
%         temp_a = reshape(detection_order_times(ci,:,1),1,[]);
%         temp_b = prctile(temp_a,50);
%         fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
%         fprintf( '%*.1f\n',10, temp_b );
%     end
%     fprintf('\n\n');
%     
%     clear temp_a temp_b temp_c
%     fprintf('Median time to second detection \n')
%     fprintf('  location: box shape; conditioning \n');
%     for ci = display_order
%         temp_a = reshape(detection_order_times(ci,:,2),1,[]);
%         temp_b = prctile( temp_a, 50 );
%         fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
%         fprintf( '%*.1f\n',10, temp_b );
%     end
%     fprintf('\n\n');
%     
%     if size( detection_order_times, 4 ) >= 3
%         clear temp_a temp_b temp_c
%         fprintf('Median time to third detection \n')
%         fprintf('  location: box shape; conditioning \n');
%         for mi = display_order
%             temp_a = reshape(detection_order_times(mi,:,3),1,[]);
%             temp_b = prctile( temp_a, 50 );
%             fprintf( '  %-50s  ', p_conditions_descriptions{mi} );
%             fprintf( '%*.1f\n',10, temp_b );
%         end
%         fprintf('\n\n');
%     end
%     
%     clear temp_a temp_b temp_c
%     fprintf('Median time from first to second detection \n')
%     fprintf('  location: box shape; conditioning \n');
%     for ci = display_order
%         temp_a = reshape(detection_order_times(ci,:,1),1,[]);
%         temp_b = reshape(detection_order_times(ci,:,2),1,[]);
%         rem_NaNs = temp_b - temp_a;
%         rem_NaNs(isnan(rem_NaNs)) = inf;
%         temp_c = prctile( rem_NaNs, 50 );
%         fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
%         fprintf( '%*.1f\n',10, temp_c );
%     end
%     fprintf('\n\n');
%     
%     if size( detection_order_times, 4 ) >= 3
%         clear temp_a temp_b temp_c
%         fprintf('Median time from second to third detection \n')
%         fprintf('  location: box shape; conditioning \n');
%         for mi = display_order
%             temp_a = reshape(detection_order_times(mi,:,2),1,[]);
%             temp_b = reshape(detection_order_times(mi,:,3),1,[]);
%             rem_NaNs = temp_b - temp_a;
%             rem_NaNs(isnan(rem_NaNs)) = inf;
%             temp_c = prctile( temp_b - temp_a, 50 );
%             fprintf( '  %-50s  ', p_conditions_descriptions{mi} );
%             fprintf( '%*.1f\n',10, temp_c );
%         end
%         fprintf('\n\n');
%     end
%     
%     clear temp_a temp_b temp_c
%     fprintf('Number of failed detections \n')
%     fprintf('  location: box shape; conditioning \n');
%     for ci = display_order
%         temp_a = sum( reshape(successful_completion(ci,:),1,[]) );
%         temp_b = numel( successful_completion(ci,:) );
%         temp_c = temp_b - temp_a;
%         fprintf( '  %-50s  ', p_conditions_descriptions{ci} );
%         fprintf( '%*d\n',10, temp_c );
%     end
%     fprintf('\n\n');

    
%% figure: object detections at various Ground Truth IOU at thresholds
  
    h3 = figure('color','white');
    set(h3,'position',[50 529 1400 450])
    for oi = 1:num_situation_objects+1
        subplot(1,num_situation_objects+1,oi);
        plot(iou_thresholds, detections_at_iou(sort_order,:,oi) );
        legend(p_conditions_descriptions(sort_order),'location','southoutside');
        if oi <= length(situation_objects)
            title([situation_objects{oi} ' detections']);
        else
            title('full situation detections');
        end
        xlabel('IOU thresholds');
        ylabel({'number of detections';['out of ' num2str(num_images)]});
        ylim([0 num_images]);
    end
    print(h3,fullfile(results_directory,'object_detections_vs_iou_threshold'),'-r300', '-dpdf','-bestfit');
    saveas(h3,fullfile(results_directory,'object_detections_vs_iou_threshold'),'png')
    
    h3b = figure('color','white');
    set(h3b,'position',[50 529 1400 450])
    for oi = 1:length(situation_objects)+1
        subplot(1,num_situation_objects+1,oi);
        plot(iou_thresholds, detections_at_iou(sort_order,:,oi) );
        legend(p_conditions_descriptions(sort_order),'location','southoutside');
        if oi <= length(situation_objects)
            title([situation_objects{oi} ' detections']);
        else
            title('full situation detections');
        end
        xlabel('IOU thresholds');
        ylabel({'number of detections';['out of ' num2str(num_images)]});
        ylim([0 num_images]);
        xlim([.35 .65]);
    end
    print(h3b,fullfile(results_directory,'object_detections_vs_iou_threshold zoomed'),'-r300', '-dpdf','-bestfit');
    saveas(h3b,fullfile(results_directory,'object_detections_vs_iou_threshold zoomed'),'png')
    
%% figure: repeat detections
% 
%     num_repeat_runs = num_images / length(unique(fnames_test_images{1}));
%     
%     %if num_repeat_runs > 1
%     
%         sum_completions = zeros(num_conditions,length(unique(fnames_test_images{1})));
%         sum_obj_detections = zeros(num_conditions,length(unique(fnames_test_images{1})),length(situation_objects) );
%         
%         for ci = 1:num_conditions
%             temp = fnames_test_images{ci};
%             [~,~,im_inds] = unique(temp);
%             for imi = 1:length(unique(fnames_test_images{1}))
%                 sum_completions(ci,imi) = sum(successful_completion(ci,eq(im_inds,imi)));
%                 for oi = 1:length(situation_objects)
%                     sum_obj_detections(ci,imi,oi) = sum(object_detections(ci,eq(im_inds,imi),oi));
%                 end
%             end  
%         end
%         
%         figure;
%         
%         for ci = 1:num_conditions
%         for oi = 1:length(situation_objects)
%             subplot2( length(situation_objects)+1,num_conditions,oi,ci);
%             stem(sort(sum_obj_detections(ci,:,oi)));
%             xlabel(situation_objects{oi});
%             if ci == 1, ylabel({'times detected'; ['(' num2str(num_repeat_runs) ' attempts)']}); end
%             if oi == 1, title(p_conditions_descriptions{ci}); end
%             ylim([0 1.1*num_repeat_runs]);
%             xlim([0 length(unique(fnames_test_images{1}))]);
%         end
%         end
%         
%         for ci = 1:num_conditions
%             subplot2( length(situation_objects)+1,num_conditions,length(situation_objects)+1,ci);
%             stem(sort(sum_completions(ci,:)));
%             xlabel('full situation');
%             if ci == 1, ylabel({'times detected'; ['(' num2str(num_repeat_runs) ' attempts)']}); end
%             ylim([0 1.1*num_repeat_runs]);
%             xlim([0 length(unique(fnames_test_images{1}))]);
%         end
%         
%     %end
%     
%     display('.');

    
    
%% figure: object detections vs time at fixed IOU threshold    
    
    
    ti = iou_threshold_index;
    h4 = figure('color','white');
    for ci = 1:num_conditions
    for oi = 1:num_situation_objects
        subplot2( num_situation_objects, num_conditions, oi, ci )
        hist( first_iteration_over_threshold(ci,:,oi,ti), 50 );
        if oi == 1, title( p_conditions_descriptions{ci} ); end
        if ci == 1, ylabel( situation_objects{oi} ); end
        xlabel('iteration number');
        %xlim([0 max(first_iteration_over_threshold(:))]);
        %ylim([0 100]);
    end
    end
    
    
    
    fig_title = 'detections per iteration at multiple thresholds';
    h5 = figure('color','white','Name',fig_title,'position',[720 2 900 600]);
    for ti = 1:num_thresholds
    for oi = 1:num_situation_objects
            
        subplot2( num_situation_objects+1, num_thresholds, oi, ti )
        if oi == num_situation_objects, subplot2( num_situation_objects+1, num_thresholds, oi, ti, oi+1, ti ); end

        for ci = 1:num_conditions
        
            detection_times = sort(reshape(first_iteration_over_threshold(ci,:,oi,ti),1,[]));
            detection_times(detection_times < 1) = nan;
            iteration_thresholds = unique( detection_times );
            cumulative_detection_ratio = zeros(1,length(iteration_thresholds));
            for ii = 1:length(iteration_thresholds)
                cur_iteration_threshold = iteration_thresholds(ii);
                cumulative_detection_ratio(ii) = sum( le( detection_times, cur_iteration_threshold ) ) / length(detection_times);
            end

            plot(iteration_thresholds,cumulative_detection_ratio);
            hold on;

            if oi == 1, title( ['detection threshold: ' num2str(iou_thresholds(ti))] ); end
            if ci == 1, ylabel( situation_objects{oi} ); end
            xlabel('iteration number');
            xlim([0 max(first_iteration_over_threshold(:))]);
            ylim([0 1]);
        end
        
        
        if oi == num_situation_objects, legend(p_conditions_descriptions,'location','southoutside'); end
        
        
    end
    end
    
    saveas(h5,fullfile(results_directory,fig_title),'png')

   
    
%% report: failed detections, final workspace 
% 
%     if show_failure_examples
%         
%         num_rows = 3;
%         num_cols = 4;
%         
%         for ci = 1:size(successful_completion,1)
%             h_temp = figure();
%             cur_display_counter = 1;
%             for ii = 1:size(successful_completion,2)
%                 if ~successful_completion(ci,ii)
%                     subplot(num_rows,num_cols,cur_display_counter);
%                     situate.draw_workspace(fnames_test_images{ci}{ii},p_conditions{ci},workspaces_final{ci,ii} );
%                     if cur_display_counter == 1
%                         title(p_conditions{ci}.description);
%                     end
%                     cur_display_counter = cur_display_counter + 1;
%                     if mod(cur_display_counter,num_rows*num_cols) == 1
%                         %figure();
%                         %cur_display_counter = 1;
%                         break;
%                     end   
%                 end
%             end
%             
%             print(h_temp,fullfile(results_directory,['failures_' p_conditions{ci}.description ]),'-r300', '-dpdf' );
%             
%         end
%         
%     end
% 
% display('fin');


%% figure: visualize the boxes generated during a run for an image
% 
% imi = 1;
% ci = 1;
% try
%     [~, im] = situate.load_image_and_data( fnames_test_images{ci}{imi}, p_conditions{ci}, true );
% catch
%     images_directory = '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking';
%     if ~exist(images_directory,'dir')
%         h = msgbox('Select directory containing image data');
%         uiwait(h);
%         images_directory = uigetdir(pwd); 
%     end
%     fnames_test_images{ci}{imi}
%         
%     
% end
% figure;
% b0 = 001;
% bf = 100;
%     
% for oi = 1:3
%     subplot(1,3,oi);
%     imshow(im); 
%     hold on;
%     obj_box_inds = find( [agent_records{ci,imi}.interest] == oi );
%     bf = min( bf, length(obj_box_inds));
%     temp = [agent_records{ci,imi}.box];
%     temp = {temp.r0rfc0cf};
%     temp = cellfun( @(x) double(x'), temp, 'UniformOutput', false );
%     cur_boxes_r0rfc0cf = cell2mat( temp )';
%     for bi = b0:bf
%         h = draw_box( cur_boxes_r0rfc0cf(obj_box_inds(bi),:)-.1, 'r0rfc0cf', 'black' );
%         set(h,'linewidth',.1);
%         h = draw_box( cur_boxes_r0rfc0cf(obj_box_inds(bi),:), 'r0rfc0cf', 'red' );
%         set(h,'linewidth',.1);
%     end
%     hold off;
%     title(p_conditions{ci}.situation_objects{oi});
%     xlabel( num2str( obj_box_inds(b0:bf) ) );
% end



% 
% 
% %% take a look at internal support, external support, and gt IOU. 
% %   this is a function of classifier and probability density, so the methods shouldn't matter. fine
% %   to just gather everything up in this case
% 
% 
% do_support_fitting = false;
% if do_support_fitting
% 
%     total_agent_records = sum( sum( cellfun( @length, agent_records ) ) );
%     columns = {'agent interest type', 'internal support', 'sample density', 'external support', 'total support', 'gt iou'};
%     data_pile_flat = nan( total_agent_records, length(columns) );
% 
%     ai = 1;
%     for ci = 1:num_conditions
%     for ii = 1:num_images
%         
%         object_of_interest = [agent_records{ci,ii}.interest];
%         object_of_interest(eq(object_of_interest,0)) = [];
%         temp               = [agent_records{ci,ii}.support];
%         total_support      = [temp.total];
%         internal_support   = [temp.internal];
%         sample_densities   = [temp.sample_densities];
%         external_support   = [temp.external];
%         gt_iou             = [temp.GROUND_TRUTH];
%         
%         temp2 = [double(object_of_interest); double(internal_support); double(sample_densities); double(external_support); double(total_support); double(gt_iou)];
%         data_pile_flat(ai:ai+length(internal_support)-1,:) = temp2';
%         
%         ai = ai + length(internal_support);
%        
%     end
%     fprintf('.');
%     end
%     
%     % remove rows with complex or infinite entries. don't know where these are coming from
%     rows_to_remove = [];
%     for ri = 1:size(data_pile_flat,1)
%         if ~all(isreal(data_pile_flat(ri,:))) || any(isinf(data_pile_flat(ri,:)))
%             rows_to_remove = [rows_to_remove ri];
%         end
%     end
%     data_pile_flat(rows_to_remove,:) = [];
%     
%     % remove rows that are all Nan, as they are allocated space for agents that didn't run
%     data_pile_flat( isnan(data_pile_flat(:,1)), : ) = [];
%     
%     % visualize support values (slow, lots of values)
%     figure
%         for ci = 1:6
%         subplot(1,6,ci);
%             if ci == 3
%                 temp = data_pile_flat(:,ci);
%                 temp( eq(temp,0) ) = min( temp( ~eq(temp,0) ) );
%                 plot(log(temp), logistic( temp, .1 ), '.' );
%                 title('log sample densities');
%             else
%                 hist(data_pile_flat(:,ci),50);
%                 title(columns(ci));
%             end
%             
%         end
%     
%     ci = 3; % density values
%     x = sort(data_pile_flat(:,ci));
%     y = cumsum( ones(size(x)) ) / length(x);
%     
%     figure;
%     subplot(2,2,1); hist(x,50); xlabel('density');
%     title('density distributions');
%     subplot(2,2,2); plot(y,x); xlabel('data percentile'); ylabel('density'); 
%     title('cumulative distribution of data')
%     subplot(2,2,3); hist(log(x),50); xlabel('log density');
%     subplot(2,2,4); plot(y,log(x)); xlabel('data percentile'); ylabel('log density');
%     
%     
%     
%     % hand drawn target activation function
%     x_hand = [ 0  .5  .9   1 ];
%     y_hand = [ 0   0   1   1 ];
%     y_interp = interp1(x_hand,y_hand,linspace(0,1,length(x)));
%     y_interp = y_interp';
%     
%     activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
%     b0 = [ 0.0480    0.5567    3.6761e-11   -0.0514];
%     
%     bf = fminsearch( @(b) sum( (y_interp - activation_function(x,b)) .^2 ), b0 );
%     
%     
%     
%     figure;
%     plot(y,y_interp,'b');
%     legend('made-up possible activation function','location','northwest');
%     hold on;
%     plot( y, activation_function(x,b0), 'green' );
%     plot( y, activation_function(x,bf), 'red' );
%     hold off;
%     legend('made-up possible activation function','guess estimate','best fit','location','northwest');
%     xlabel('data percentile');
%     ylabel('external support value');
%     xlim([-.1 1.1]);
%     ylim([-.1 1.1]);
%     
%     
%     
%     %% fit total support to gt IOU
%     
%     object_type      = data_pile_flat(:,1);
%     internal_support = data_pile_flat(:,2);
%     densities        = data_pile_flat(:,3);
%     external_support = activation_function( densities, bf );
%     gt_iou           = data_pile_flat(:,6);
%     
%     b0_total = [0 1 1 0];
%     bf_total = zeros( length(situation_objects), length(b0_total) );
%     for oi = 1:length(situation_objects)
%         cur_inds = eq(object_type,oi);
%         cur_internal = internal_support(cur_inds);
%         cur_external = external_support(cur_inds);
%         cur_gt_iou   = gt_iou(cur_inds);
%         
%         resampled_inds = resample_to_uniform( cur_gt_iou, 2*length(cur_gt_iou) );
%         cur_internal = cur_internal( resampled_inds );
%         cur_external = cur_external( resampled_inds );
%         cur_gt_iou   = cur_gt_iou(   resampled_inds );
%         
%         target_value = cur_gt_iou;
%         %bf_total(oi,:) = fminsearch( @(b) sum((  target_value - (b(1) + b(2)*cur_internal + b(3)*cur_external + b(4)*cur_internal.*cur_external)  ).^2), b0_total );
%         bf_total(oi,:) = fminsearch( @(b) sum((  target_value - logistic(b(1) + b(2)*cur_internal + b(3)*cur_external + b(4)*cur_internal.*cur_external)  ).^2), b0_total );
%         fprintf('.');
%     end
%     
%     % see how it did
%     figure
%     for oi = 1:length(situation_objects)
%         cur_b = bf_total(oi,:);
%         
%         cur_inds = eq(object_type,oi);
%         cur_internal = internal_support(cur_inds);
%         cur_external = external_support(cur_inds);
%         cur_gt_iou   = gt_iou(cur_inds);
%         
% %         resampled_inds = resample_to_uniform( cur_gt_iou );
% %         cur_internal = cur_internal( resampled_inds );
% %         cur_external = cur_external( resampled_inds );
% %         cur_gt_iou   = cur_gt_iou(   resampled_inds );
%         
%         %cur_total = cur_b(1) + cur_b(2)*cur_internal + cur_b(3)*cur_external + cur_b(4)*cur_internal.*cur_external;
%         cur_total = logistic( cur_b(1) + cur_b(2)*cur_internal + cur_b(3)*cur_external + cur_b(4)*cur_internal.*cur_external );
%         
%         subplot(1,length(situation_objects),oi);
%         plot(cur_gt_iou,cur_total,'.');
%         title(situation_objects{oi})
%         xlabel('gt iou');
%         ylabel('est iou');
%     end
%     
%     %% fit total support for >.5
%     
%     % now fitting total support using the learned external support function
%     object_type      = data_pile_flat(:,1);
%     internal_support = data_pile_flat(:,2);
%     densities        = data_pile_flat(:,3);
%     external_support = activation_function( densities, bf );
%     gt_iou           = data_pile_flat(:,6);
%     
%     b0_total = [0 1 1 0];
%     bf_total = zeros( length(situation_objects), length(b0_total) );
%     for oi = 1:length(situation_objects)
%         cur_inds = eq(object_type,oi);
%         cur_internal = internal_support(cur_inds);
%         cur_external = external_support(cur_inds);
%         cur_gt_iou   = gt_iou(cur_inds);
%         
%         resampled_inds = resample_to_uniform( cur_gt_iou );
%         cur_internal = cur_internal( resampled_inds );
%         cur_external = cur_external( resampled_inds );
%         cur_gt_iou   = cur_gt_iou(   resampled_inds );
%         
%         target_value = ge( cur_gt_iou, .5 );
%         bf_total(oi,:) = fminsearch( @(b) sum((  target_value - logistic(b(1) + b(2)*cur_internal + b(3)*cur_external + b(4)*cur_internal.*cur_external)  ).^2), b0_total );
%         fprintf('.');
%     end
%     
%     % see how it did
%     figure
%     for oi = 1:length(situation_objects)
%         cur_b = bf_total(oi,:);
%         
%         cur_inds = eq(object_type,oi);
%         cur_internal = internal_support(cur_inds);
%         cur_external = external_support(cur_inds);
%         cur_gt_iou   = gt_iou(cur_inds);
%         
% %         resampled_inds = resample_to_uniform( cur_gt_iou );
% %         cur_internal = cur_internal( resampled_inds );
% %         cur_external = cur_external( resampled_inds );
% %         cur_gt_iou   = cur_gt_iou(   resampled_inds );
%         
%         cur_total = logistic( cur_b(1) + cur_b(2)*cur_internal + cur_b(3)*cur_external + cur_b(4)*cur_internal.*cur_external );
%         
%         subplot(1,length(situation_objects),oi);
%         plot(cur_gt_iou,cur_total,'.');
%         title(situation_objects{oi})
%         xlabel('gt iou');
%         ylabel('est iou');
%     end
%     
%     
%     
%     %% fitting external and total support in one shot
%     
%     object_type = data_pile_flat(:,1);
%     internal_support = data_pile_flat(:,2);
%     densities = data_pile_flat(:,3);
%     % external_support = logistic( log(data_pile_flat(:,3)), .1);
%     gt_iou = data_pile_flat(:,6);
%     
%     %iou_estimate_function = @(internal,density,b) b(1) + b(2) * internal + b(3) * activation_function(density,b(5:8)) + b(4) * internal .* activation_function(density,b(5:8));
%     iou_estimate_function = @(internal,density,b) b(1) * internal + b(2) * activation_function(density,[0 1 b(4) b(5)]) + b(3) * internal .* activation_function(density,[0 1 b(4) b(5)]);
%     b0 = [1 1 1 10e-12 0]; % internal, external, mixing, a,b,c,d
%     figure
%     bfs = zeros(length(situation_objects),length(b0));
%     for oi = 1:3
%         
%         if any(logical(bfs(oi,:)))
%             b0 = bfs(oi,:);
%         else
%             b0 = [1 1 1 10e-12 0];
%         end
%         
%         cur_inds = eq(object_type,oi);
%         
%         cur_internal_support = internal_support(cur_inds);
%         cur_densities   = densities(cur_inds);
%         cur_gt_iou           = gt_iou(cur_inds);
%         resampled_inds = resample_to_uniform(cur_gt_iou,[],10);
%         
%         cur_internal_support = cur_internal_support(resampled_inds);
%         cur_densities = cur_densities(resampled_inds);
%         cur_gt_iou = cur_gt_iou(resampled_inds);
%         
%         bfs(oi,:) = fminsearch( @(b) sum( (cur_gt_iou - iou_estimate_function(cur_internal_support,cur_densities,b) ) .^2 ), b0 );
%         
%         fprintf('.');
%     end
%     fprintf('\n');
%     
%     figure
%     for oi = 1:length(situation_objects)
%         
%         cur_inds = eq(object_type,oi);
%         iou_estimate = iou_estimate_function( internal_support(cur_inds), densities(cur_inds), bfs(oi,:));
%         
%         subplot(1,3,oi)
%         plot(gt_iou(cur_inds),iou_estimate,'.');
%         title(situation_objects{oi});
%         xlabel('gt iou');
%         ylabel('predicted iou');
%         
%     end
%     
%     
% end 
% 
%     
%     
% 

end




