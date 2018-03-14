


function situate_experiment_analysis( results_directory, show_final_workspaces, rcnn_csv_results_directory )
% situate_experiment_analysis( results_directory, show_final_workspaces, [rcnn_csv_results_directory] );

    if exist('rcnn_results_directory','var') && ~isempty(rcnn_csv_results_directory) && exist(rcnn_csv_results_directory,'dir')
        include_rcnn_results = true; 
    else
        include_rcnn_results = false;
    end
    
    if ~exist('show_final_workspaces','var') || isempty(show_final_workspaces)
        show_final_workspaces = true;
    end
    
    
    
%% data source 

    if ~exist( 'results_directory', 'var' ) || isempty(results_directory) || ~isdir(results_directory)

        h = msgbox('Select directory containing the results to analyze');
        uiwait(h);
        results_directory = uigetdir(pwd);
        if isempty(results_directory) || isequal(results_directory,0)
            return;
        end

    end

    temp = dir(fullfile(results_directory, '*.mat'));
    fn = cellfun( @(x) fullfile(results_directory,x), {temp.name}, 'UniformOutput', false );
    
    
    
%% group on condition
   
    % just get the description for grouping
    p_conditions_per_file = cell(1,length(fn));
    p_conditions_descriptions_temp = cell(1,length(fn));
    for fi = 1:length(fn) % file ind
        temp = load(fn{fi},'p_condition');
        p_conditions_per_file{fi} = temp.p_condition;
        p_conditions_descriptions_temp{fi} = temp.p_condition.description;
        progress(fi,length(fn),'loading parameterization data');
    end
    
    [p_conditions_descriptions,~,condition_indices] = unique(p_conditions_descriptions_temp);
    num_conditions = length(p_conditions_descriptions);
    
    
    
%% reshape the data

    results_per_condition                           = [];
    results_per_condition.condition                 = '';
    results_per_condition.iou_thresholds            = [];
    results_per_condition.detections_at_iou         = [];
    results_per_condition.first_iteration_over_threshold = [];
    results_per_condition.first_iteration_over_threshold_desc = '';
    results_per_condition.final_ious                = [];
    results_per_condition.final_ious_desc           = '';
    results_per_condition.support_record.internal   = [];
    results_per_condition.support_record.external   = [];
    results_per_condition.support_record.total      = [];
    results_per_condition.support_record.gt_iou     = [];
    results_per_condition = repmat( results_per_condition, 1, num_conditions);
    
    % load up related files, combine
    for ci = 1:num_conditions
        
        cur_files_inds = find(eq(ci,condition_indices));
        temp_data = cell(1,length(cur_files_inds));
        for fii = 1:length(cur_files_inds)
            fi = cur_files_inds(fii); % indx for file associated with current condition
            cur_fname = fn{fi};
            fprintf('condition: %i trial: %i fname: %s \n', ci,fii,cur_fname);
            temp_data{fii} = load(cur_fname,'fnames_im_test','workspaces_final','p_condition','agent_records');
        end
        
        p_condition = temp_data{1}.p_condition; % because they should have the same conditions, just use the first one
        situation_objects = p_condition.situation_objects;
        num_situation_objects = length(situation_objects );
        
        original_file_ind = [];
        for ti = 1:length(temp_data)
            unrun_workspaces = cellfun(@isempty, temp_data{ti}.workspaces_final );
            temp_data{ti}.fnames_im_test(unrun_workspaces) = [];
            temp_data{ti}.workspaces_final(unrun_workspaces) = [];
            temp_data{ti}.agent_records(unrun_workspaces) = [];
            original_file_ind(end+1:end+length(temp_data{ti}.workspaces_final)) = cur_files_inds( ti );
        end
        
        workspaces_final = cellfun( @(x) x.workspaces_final, temp_data, 'UniformOutput', false);
        workspaces_final = cellfun( @(x) [x{:}], workspaces_final, 'UniformOutput', false);
        workspaces_final = [workspaces_final{:}];
        
        agent_records = cellfun( @(x) x.agent_records, temp_data, 'UniformOutput', false);
        agent_records = cellfun( @(x) [x{:}], agent_records, 'UniformOutput', false);
        agent_records = [agent_records{:}]';
        
        fnames_test = cellfun( @(x) x.fnames_im_test, temp_data, 'UniformOutput', false);
        fnames_test = cellfun( @(x) x', fnames_test,'UniformOutput',false);
        try
            fnames_test = [fnames_test{:}];
        catch
            fnames_test = vertcat(fnames_test{:});
        end
        fnames_test = fnames_test(:)';
        
        for wi = 1:length(workspaces_final)
            [path, name, ext] = fileparts( fnames_test{wi} );
            labl_fname = fullfile( path, [name '.json'] );
            workspaces_final(wi) = situate.workspace_score( workspaces_final(wi), labl_fname, p_conditions_per_file{original_file_ind(wi)} );
        end
        
        results_per_condition(ci).condition = p_condition.description;
        results_per_condition(ci).workspaces_final = workspaces_final;
        
        % detections at threshold, iteration
        num_thresholds = 10;
        iou_thresholds = sort(unique([linspace(0,1,num_thresholds+1) .5])); % make sure .5 is in there
        iou_thresholds = iou_thresholds(2:end);
        num_thresholds = length(iou_thresholds);
        num_images     = numel(fnames_test);
        if num_images > length(workspaces_final)
            warning('looks like there are more image names that finished workspaces');
            num_images = length(workspaces_final);
        end
        
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
        results_per_condition(ci).iou_thresholds  = iou_thresholds;
        results_per_condition(ci).final_ious      = final_ious;
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
        
        
        
        % time of first detections ( over GT IOU threshold + over .5 total support )
        first_iteration_over_threshold = zeros( num_images, num_situation_objects+1, num_thresholds );

        for ii = 1:num_images
        for ti = 1:num_thresholds
            
            for oi = 1:num_situation_objects

                iterations_of_interest = find([agent_records(ii,:).interest] == oi);
                temp             = [agent_records(ii,:).support];
                temp             = temp(iterations_of_interest);
                internal_support = [temp.internal];
                external_support = [temp.external];
                total_support    = [temp.total];
                gt_iou           = [temp.GROUND_TRUTH];

                % first with an actual gt_iou over threshold 
                % and total support over threshold (using .5 total support)
                % first_over_threshold = find( ge( gt_iou, iou_thresholds(ti) ), 1, 'first' );
                first_over_threshold = find( ge( gt_iou, iou_thresholds(ti) ) & ge( total_support, iou_thresholds(ti) ), 1, 'first' );

                clear internal_support external_support total_support gt_iou temp;
                
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
        
        
        % trace of what scouts were looking for at each iteration (25 images per method)
        
        % show what scouts were looking for during the run (with final IOU info in the title)
        figure('Name',['scout trace: ' p_conditions_descriptions{ci}]);
        num_subplots = min(25,num_images);
        for imi = 1:num_subplots
            subplot_lazy(num_subplots,imi);
            agent_interests = double([agent_records(imi,:).interest]);
            perturbation = .1 * randn(size(agent_interests));
            perturbation( eq( agent_interests, 0 ) ) = 0;
            
            tempsupport = [agent_records(imi,:).support];
            agent_total_support = [tempsupport.total];
            agent_total_support(end+1:length(agent_interests)) = 0;
            inds_under = find(agent_total_support' <  p_condition.thresholds.total_support_final);
            inds_over  = find(agent_total_support' >= p_condition.thresholds.total_support_final);
            
            plot( inds_under, agent_interests(inds_under) + perturbation(inds_under), '.', 'Color', [.5 .5 1]);
            hold on;
            plot( inds_over, agent_interests(inds_over) + perturbation(inds_over), '.r');
            
            ylim([-.5 3.5])
            set( gca, 'YTick', 0:3);
            set( gca, 'YTickLabel', ['none' situation_objects] );
            
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
        for ti  = 1:num_thresholds
        for oi  = 1:num_situation_objects + 1
        for imi = 1:num_images
            cur_detection_ind = first_iteration_over_threshold(imi,oi,ti);
            % add to detections if it's a specific object that was detected
            % OR if it was the last object to be checked in over threshold for a situation that was
            % still checked in by the end. Edge case we're avoiding: all three objects were checked in at
            % some point (maybe not at the same time) but the situation was not correctly found in
            % the end. 
            
            do_add_to_detections = ~isnan(cur_detection_ind) ...
                && ( ~oi==num_situation_objects+1 || all( final_ious(imi,:)>=iou_thresholds(ti) ) );
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
        final_ious                      = zeros( num_conditions, num_images,     num_situation_objects );
        detections_at_iou               = zeros( num_conditions, num_thresholds, num_situation_objects + 1 );
        first_iteration_over_threshold  = zeros( num_conditions, num_images,     num_situation_objects + 1, num_thresholds );
        detections_at_num_proposals     = zeros( num_conditions, num_thresholds, num_situation_objects + 1, p_condition.num_iterations );
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
    
        
        
%% clean up a little
    
    clear temp_data;
    clear agent_records;
    clear temp;
    
    
    
%% median detection times
iou_threshold_ind = find(eq( abs(iou_thresholds - .5 ), min(abs(iou_thresholds - .5 ))));
median_detections = nan( num_conditions, num_situation_objects + 1 );
for ci = 1:num_conditions
for oi = 1:num_situation_objects + 1
    temp = results_per_condition(ci).first_iteration_over_threshold(:,oi,iou_threshold_ind);
    temp( isnan(temp) ) = p_condition.num_iterations + 1;
    median_detections(ci,oi) = median(temp);
end
end
    


%% include rcnn results

% include jordan's rcnn data source
if include_rcnn_results

    % need to go back and update this
    error('need to update rcnn inclusion');
    testing_image_file_directory = '?';
    [confidences, gt_ious, boxes_xywh, output_labels, per_row_fnames] = rcnn_csvs_process( rcnn_csv_results_directory, fnames_test, testing_image_file_directory );
    
end
    
    

%% define display order of conditions, color and line specifications 

    proposals_display_limit = p_condition.num_iterations;
    % proposals_display_limit = 1000;

    linespec = {'-','--','-.',':'};
    linespec = repmat(linespec,1,ceil(num_conditions/length(linespec)));

    % figure out a display order that emphasizes completed situation detections
    iou_threshold_index = find(eq(min(abs(iou_thresholds-.5)),abs(iou_thresholds-.5)));
    full_situation_index = num_situation_objects + 1;
    [~,display_order] = sort( detections_at_num_proposals(:,iou_threshold_index,full_situation_index,proposals_display_limit), 'descend' );
    
    % define color space
    colors = zeros( num_conditions,3); % all black
    
    
    
%% figure: completed detections as a function of iterations 

    h2 = figure();
    h2.Color = [1 1 1];
    hold on;
    
    detection_rate_at_num_proposals = detections_at_num_proposals / num_images;
    
    for i = 1:length(display_order)
        ci = display_order(i);
        cur_data = detection_rate_at_num_proposals(ci,iou_threshold_index,num_situation_objects+1,:);
        cur_data = squeeze(cur_data);
        plot( cur_data, 'Color', colors(i,:), 'LineWidth', 1.25, 'LineStyle', linespec{i} );
        % condition, threshold, object, iteration
    end
    hold off;
    
     if include_rcnn_results
        rcnn_detections = rcnn_situation_detections_at_threshold(find(eq(iou_thresholds,.5)));
        rcnn_detection_rate = rcnn_detections / length(unique_fnames);
        hold on;
        plot( proposals_display_limit, rcnn_detection_rate, 'or');
    end
    
    hold on;
        plot([0 proposals_display_limit], [num_images, num_images], '--blue')
    hold off;
    
   
    
    box(h2.CurrentAxes,'on');
    
    xlabel(  'Iterations' );
    ylabel({ 'Situation Detection Rate', ['(Cumulative, ' num2str(num_images) 'images)'] });
 
    xlim([0 proposals_display_limit]);
    ylim([0 1.1]);
    
    % legend(unique_descriptions(display_order),'Location','Northeast');
    title_string = 'Situation recognition method';
    if include_rcnn_results
        h_temp = legend([p_conditions_descriptions(display_order) 'R-CNN'],'Location','eastoutside','FontName','FixedWidth');
    else
        h_temp = legend(p_conditions_descriptions(display_order),'Location','eastoutside','FontName','FixedWidth');
    end
    h_temp.FontSize = 8;
    try % works in matlab2016a, not 2015 versions apparently
        h_temp.Title.String = title_string;
    end
    
    h2.Position = [440 537 560 220];
    saveas(h2,fullfile(results_directory,'situate_experiment_figure detections at iteration'),'png');
    
    max_val = max([.01; max(reshape(detection_rate_at_num_proposals(:,iou_threshold_index,num_situation_objects+1,:),1,[]))]);
    if include_rcnn_results
        max_val = max( max_val, rcnn_detection_rate );
    end
    ylim([0, 1.1*max_val ]);
    saveas(h2,fullfile(results_directory,'situate_experiment_figure detections at iteration zoomed'),'png');
    

    
%% figure: object detections at various Ground Truth IOU at thresholds
  
    h3 = figure('color','white');
    set(h3,'position',[50 529 1400 450])
    for oi = 1:num_situation_objects+1
        subplot(1,num_situation_objects+1,oi);
        plot(iou_thresholds, detections_at_iou(display_order,:,oi) );
        
        if include_rcnn_results
            hold on;
            plot( iou_thresholds, rcnn_detections_at_threshold(:,oi)  );
            legend([p_conditions_descriptions(display_order) 'R-CNN'],'location','southoutside');
        else
            legend(p_conditions_descriptions(display_order),'location','southoutside');
        end
        
        if oi <= length(situation_objects)
            title([situation_objects{oi} ' detections']);
        else
            title('full situation detections');
        end
        xlabel('IOU thresholds');
        ylabel({'number of detections';['out of ' num2str(num_images)]});
        ylim([0 num_images]);
    end
    saveas(h3,fullfile(results_directory,'object_detections_vs_iou_threshold'),'png')
   
    
    
%% figure: repeat detections

    [fnames_unique,fname_counts,fname_assignment_inds] = unique_cell( fnames_test );
    
    % threshold for which this would have been considered a detection
    min_detection_threshold = zeros( num_conditions, num_images );
    for ci = 1:num_conditions
        min_detection_threshold(ci,:) = min(squeeze(final_ious(ci,:,:)),[],2);
    end
    
    assert( all( eq( fname_counts(1), fname_counts ) ) );
    num_repeat_runs = fname_counts(1);
    
    per_image_detection_counts = zeros( num_conditions, length(fnames_unique) );
    for ci = 1:num_conditions
    for imi = 1:length(fnames_unique)
        per_image_detection_counts(ci,imi) = sum( ge( min_detection_threshold( ci, eq( imi, fname_assignment_inds ) ), .5 ) );
    end
    end
    
    figure
    for ci = 1:num_conditions
        subplot(1,num_conditions,ci);
        stem( sort( per_image_detection_counts( ci,: ) ) );
    end
        
    
    
%% figure: object detections vs time at fixed IOU threshold    
    
    fig_title = 'detection iteration by method and object';
    ti = iou_threshold_index;
    h4 = figure('color','white','Name',fig_title);
    for oi = 1:num_situation_objects
        max_bin_height_for_object_type = 0;
        for ci = 1:num_conditions
            subplot2( num_situation_objects, num_conditions, oi, ci )
            hist( first_iteration_over_threshold(ci,:,oi,ti), 50 );
            if oi == 1, title( p_conditions_descriptions{ci} ); end
            if ci == 1, ylabel( situation_objects{oi} ); end
            xlabel('iteration number');
            %xlim([0 max(first_iteration_over_threshold(:))]);
            %ylim([0 100]);

            % store bin heights
            temp = get(gca,'YLim');
            if temp(2) > max_bin_height_for_object_type, max_bin_height_for_object_type = temp(2); end
        end
        % set all plots for same obj type to have same y scale
        for ci = 1:num_conditions
            subplot2( num_situation_objects, num_conditions, oi, ci );
            ylim([0 max_bin_height_for_object_type]);
        end
    end
    
    saveas(h4,fullfile(results_directory,fig_title),'png')
    
    
    
    
    fig_title = 'detections per iteration at multiple thresholds';
    h5 = figure('color','white','Name',fig_title,'position',[720 2 900 600]);
    for ti = 1:num_thresholds
    for oi = 1:num_situation_objects+1
            
        % first_iteration_over_threshold( condition_ind, image_ind, object_ind, threshold_ind )
        
        subplot2( num_situation_objects+2, num_thresholds, oi, ti )
        if oi == num_situation_objects+1, subplot2( num_situation_objects+2, num_thresholds, oi, ti, oi+1, ti ); end

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

            if oi == 1, title( ['iou > ' num2str(iou_thresholds(ti))] ); end
            if ci == 1 
                if oi < length(situation_objects)
                    ylabel( situation_objects{oi} ); 
                else
                    ylabel('full situation');
                end
            end 
            xlabel('iteration number');
            xlim([0 max(first_iteration_over_threshold(:))]);
            ylim([0 1]);
        end
        
        
        if oi == num_situation_objects + 1 && ti == num_thresholds, legend(p_conditions_descriptions,'location','southeast'); end
        
        
    end
    end
    
    saveas(h5,fullfile(results_directory,fig_title),'png')

   
    
%% show final workspaces

    if show_final_workspaces
    
        for ci = 1:num_conditions

            max_to_show = 16;
            num_to_show = min(max_to_show,length(fnames_test));
            
            figure;
            for imi = 1:num_to_show
                subplot_lazy(num_to_show,imi);
                if ~exist(fnames_test{imi},'file')
                    [fpath,fname,ext] = fileparts( fnames_test{imi} );
                    switch fpath
                        case '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking_test'
                            fpath = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
                        otherwise
                            error('having an image path problem');
                    end
                    cur_fname = fullfile( fpath, [fname ext] );
                else
                    cur_fname = fnames_test{imi};
                end
                
                situate.workspace_draw( cur_fname, p_conditions_per_file{ci}, results_per_condition(ci).workspaces_final(imi), 12 );
                
            end

        end
        
    end



end



