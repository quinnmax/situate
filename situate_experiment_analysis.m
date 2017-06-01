


function situate_experiment_analysis( results_directory, show_failure_examples )
% situate_experiment_analysis( results_directory, show_failure_examples );


%% data source 

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
    fnames_test_images_temp = {};
    % run_data_temp = {};
    
    for fi = 1:length(fn) % file ind
        temp_d = load(fn{fi});
        p_conditions_temp{end+1}           = temp_d.p_condition;
        p_conditions_descriptions_temp{fi} = temp_d.p_condition.description;
        agent_records_temp{end+1}          = temp_d.agent_records;
        workspaces_final_temp{end+1}       = temp_d.workspaces_final;
        fnames_test_images_temp{end+1}     = temp_d.fnames_im_test;
    end
    
    [description_counts, p_conditions_descriptions] = counts( p_conditions_descriptions_temp );
    num_conditions = length(p_conditions_descriptions);
    
    % check that things seem balanced
    if ~all(eq(description_counts(1), description_counts)), error('different numbers of runs for different experimental conditions'); end
    images_per_run = cellfun( @length, workspaces_final_temp );
    if ~all(eq(images_per_run(1),images_per_run)), error('different numbers of images in different runs'); end
    
    num_images = sum( cellfun( @length, workspaces_final_temp ) ) / length(p_conditions_descriptions);
 
    
%% group on condition
    
    workspaces_final           = cell( num_conditions, num_images );
    agent_records              = cell( num_conditions, num_images );
    p_conditions               = cell( num_conditions, 1 );
    fnames_test_images         = cell( num_conditions, 1 );
    
    for ci = 1:num_conditions
        cur_condition_inds = strcmp( p_conditions_descriptions{ci}, p_conditions_descriptions_temp );
        p_conditions(ci) = p_conditions_temp(find(cur_condition_inds,1,'first'));
        workspaces_final(ci,:)  = [workspaces_final_temp{cur_condition_inds}];
        agent_records(ci,:)     = [agent_records_temp{cur_condition_inds}];
        fnames_test_images{ci}  = reshape([fnames_test_images_temp{cur_condition_inds}],[],1);
    end

    clear temp_d
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
    
    iou_threshold = .5;
    detection_order_times  = inf(  num_conditions, num_images, length(p_conditions{1}.situation_objects) );
    detection_order_labels = cell( num_conditions, num_images, length(p_conditions{1}.situation_objects) );
    for ci = 1:num_conditions
    for ii = 1:num_images
        situation_objects = p_conditions{ci}.situation_objects;
        temp_detection_times = inf(1,length(situation_objects));
        cur_support_record = [agent_records{ci,ii}.support];
        for oi = 1:length(situation_objects)
            workspace_entry_event_inds_over_threshold = ge( round(100*[cur_support_record.total])/100, iou_threshold );
            interest_records = [agent_records{ci,ii}.interest];
            interest_records(length(workspace_entry_event_inds_over_threshold)+1:end) = [];
            workspace_entry_event_inds_object_type = oi == interest_records;
            
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
    
    linespec = {'-','--','-.',':'};
    linespec = repmat(linespec,1,ceil(length(include_conditions)/length(linespec)));

    [~,sort_order] = sort(sum(detections_at_num_proposals(:,1:min(proposals_display_limit,size(detections_at_num_proposals,2))),2), 'descend');

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

    
%% figure: object detections at various Ground Truth IOU at thresholds
  
    final_ious = cell(1,num_conditions);
    for ci = 1:num_conditions, final_ious{ci }= zeros( num_images, length(situation_objects)  ); end
    
    for ci = 1:num_conditions
    for ii = 1:num_images
        for oi = 1:length( p_conditions{ci}.situation_objects )
            w_ind = find( strcmp( workspaces_final{ci,ii}.labels, situation_objects{oi} ),1);
            if ~isempty(w_ind), final_ious{ci}(ii,oi) = workspaces_final{ci,ii}.GT_IOU(w_ind); 
            else final_ious{ci}(ii,oi) = 0;
            end
        end
    end
    end
    
    iou_thresholds = (0:10)./10;
    detections_at_iou = zeros( num_conditions, length(iou_thresholds), length( situation_objects ));
    situation_detections_at_iou = zeros( num_conditions, length(iou_thresholds) );
    
    for ci = 1:num_conditions
    for ti = 1:length(iou_thresholds)
        detections_at_iou(ci,ti,:) = sum(ge( final_ious{ci}, iou_thresholds(ti) ));
        situation_detections_at_iou(ci,ti) = sum( prod( ge( final_ious{ci}, iou_thresholds(ti)), 2 ) );
    end
    end
    
    h3 = figure('color','white');
    for oi = 1:length(situation_objects)
        subplot(1,length(situation_objects)+1,oi);
        plot(iou_thresholds,detections_at_iou(:,:,oi));
        xlabel('IOU threshold');
        ylabel('detections');
        title([situation_objects{oi} ' detections']);
        ylim([0 num_images]);
        legend(p_conditions_descriptions);
    end
    subplot( 1,length(situation_objects)+1,length(situation_objects)+1)
    plot( iou_thresholds, situation_detections_at_iou);
    xlabel('IOU threshold');
    ylabel('detections');
    title('full situation detections');
    ylim([0 num_images]);
    legend(p_conditions_descriptions);
    
    
    print(h3,fullfile(results_directory,'object_detections_vs_iou_threshold'),'-r300', '-dpdf' );
    
    
%% figure: object detections vs time at fixed IOU threshold    
    
    iou_thresholds = [.25 .5 .75 .9];
    num_thresholds = length(iou_thresholds);
    num_situation_objects = length(p_conditions{1}.situation_objects);
    first_iteration_over_threshold = zeros( num_conditions, num_images, num_situation_objects, num_thresholds );

    for ci = 1:num_conditions
    for ii = 1:num_images
    for oi = 1:num_situation_objects
    for ti = 1:num_thresholds
        
        iterations_of_interest = find([agent_records{ci,ii}.interest] == oi);
        
        temp             = [agent_records{ci,ii}.support];
        temp             =  temp(iterations_of_interest);
        internal_support = [temp.internal];
        total_support    = [temp.total];
        gt_iou           = [temp.GROUND_TRUTH];
        
        first_over_threshold = find( gt( gt_iou, iou_thresholds(ti) ), 1, 'first' );
        if ~isempty(first_over_threshold)
            first_iteration_over_threshold(ci,ii,oi,ti) = iterations_of_interest( first_over_threshold );
        else
            first_iteration_over_threshold(ci,ii,oi,ti) = -1000;
        end
        
    end
    end
    end
    end
    
    ti = 1;
    
    figure('color','white')
    for ci = 1:num_conditions
    for oi = 1:num_situation_objects
        subplot2( num_situation_objects, num_conditions, oi, ci )
        hist( reshape(first_iteration_over_threshold(ci,:,oi,ti),1,[]), 50 );
        if oi == 1, title( p_conditions_descriptions{ci} ); end
        if ci == 1, ylabel( p_conditions{1}.situation_objects{oi} ); end
        xlabel('iteration number');
        xlim([0 max(first_iteration_over_threshold(:))]);
        ylim([0 100]);
    end
    end

    
%% display IOU for each object type and each image

    final_ious = cell(1,num_conditions);
    iou_threshold = .5;
    for ci = 1:num_conditions
        final_ious{ci} = zeros(num_images, length(p_conditions{ci}.situation_objects) );
        for ii = 1:num_images
            for oi = 1:length(p_conditions{ci}.situation_objects)
                oi_workspace_ind = find(strcmp(p_conditions{ci}.situation_objects{oi}, workspaces_final{ci,ii}.labels),1);
                if ~isempty(oi_workspace_ind)
                    final_ious{ci}(ii,oi) = workspaces_final{ci,ii}.GT_IOU(oi_workspace_ind);
                else
                    final_ious{ci}(ii,oi) = 0; % no op
                end
            end
            
            if isequal( sort(workspaces_final{ci,ii}.labels), sort(p_conditions{ci}.situation_objects) )...
            && all(workspaces_final{ci,ii}.GT_IOU >= iou_threshold)
                successful_completion(ci,ii) = true;
            end
        end
    end
    
    for ci = 1:num_conditions
        display(p_conditions_descriptions{ci});
        
        fprintf('  sorted by total IOU support\n');
        display(p_conditions{ci}.situation_objects);
        [~,sort_i] = sort(sum(final_ious{1},2),'descend');
        display( final_ious{1}(sort_i,:) )

        fprintf('  sorted by minimum IOU\n');
        display(p_conditions{ci}.situation_objects);
        [~,sort_i] = sort(min(final_ious{1},[],2),'descend');
        display( final_ious{1}(sort_i,:) )
    end

    
%% report: failed detections, final workspace 

    if show_failure_examples
        
        num_rows = 3;
        num_cols = 4;
        
        for ci = 1:size(successful_completion,1)
            h_temp = figure();
            cur_display_counter = 1;
            for ii = 1:size(successful_completion,2)
                if ~successful_completion(ci,ii)
                    subplot(num_rows,num_cols,cur_display_counter);
                    situate.draw_workspace(fnames_test_images{ci}{ii},p_conditions{ci},workspaces_final{ci,ii} );
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
            
            print(h_temp,fullfile(results_directory,['failures_' p_conditions{ci}.description ]),'-r300', '-dpdf' );
            
        end
        
    end

display('fin');


%% take at how many scouts were looking for each object type during the run
  
figure

rows = min( size( agent_records,2), 10 );
cols = size(agent_records,1);

for imi = 1:rows
for ci = 1:cols
  
        subplot2(rows, cols, imi, ci); 
        hist(double([agent_records{ci,imi}.interest]))
        ylim([0 length(agent_records{1,1})]);
        title(p_conditions{ci}.description);
        xticks([1,2,3])
        xticklabels(p_conditions{ci}.situation_objects)
        xlim([0 4]);

end
end


%% visualize the boxes generated during a run for an image

imi = 1;
ci = 1;
[~, im] = situate.load_image_and_data( fnames_test_images{ci}{imi}, p_conditions{ci}, true );
figure;
b0 = 001;
bf = 100;
    
for oi = 1:3
    subplot(1,3,oi);
    imshow(im); 
    hold on;
    obj_box_inds = find( [agent_records{ci,imi}.interest] == oi );
    bf = min( bf, length(obj_box_inds));
    temp = [agent_records{ci,imi}.box];
    temp = {temp.r0rfc0cf};
    temp = cellfun( @(x) double(x'), temp, 'UniformOutput', false );
    cur_boxes_r0rfc0cf = cell2mat( temp )';
    for bi = b0:bf
        h = draw_box( cur_boxes_r0rfc0cf(obj_box_inds(bi),:)-.1, 'r0rfc0cf', 'black' );
        set(h,'linewidth',.1);
        h = draw_box( cur_boxes_r0rfc0cf(obj_box_inds(bi),:), 'r0rfc0cf', 'red' );
        set(h,'linewidth',.1);
    end
    hold off;
    title(p_conditions{ci}.situation_objects{oi});
    xlabel( num2str( obj_box_inds(b0:bf) ) );
end



%% take a look at internal support, external support, and gt IOU. 
%   this is a function of classifier and probability density, so the methods shouldn't matter. fine
%   to just gather everything up in this case

    total_agent_records = sum( sum( cellfun( @length, agent_records ) ) );
    columns = {'agent_interest_type', 'internal_support', 'external_support', 'total_support', 'gt_iou'};
    data_pile_flat = -5 * ones( total_agent_records, length(columns) );

    ai = 1;
    for ci = 1:num_conditions
    for ii = 1:num_images
        
        object_of_interest = [agent_records{ci,ii}.interest];
        object_of_interest(eq(object_of_interest,0)) = [];
        temp               = [agent_records{ci,ii}.support];
        total_support      = [temp.total];
        internal_support   = [temp.internal];
        external_support   = [temp.external];
        gt_iou             = [temp.GROUND_TRUTH];
        
        temp2 = [double(object_of_interest); double(internal_support); double(external_support); double(total_support); double(gt_iou)];
        data_pile_flat(ai:ai+length(internal_support)-1,:) = temp2';
        
        ai = ai + length(internal_support);
       
    end
    fprintf('.');
    end
    
    % external support wasn't recorded for all of them, so infer it from total support
    external_support = (data_pile_flat(:,4) - .8 * data_pile_flat(:,2)) ./ .2;
    external_support( external_support < 0 | isnan(external_support) ) = 0;
    
    b = zeros( num_situation_objects, 4 );
    for oi = 1:num_situation_objects
        rows_of_interest = eq( oi, data_pile_flat(:,1));
        internal = data_pile_flat(rows_of_interest,2);
        external = external_support(rows_of_interest);
        x = [ ones(length(internal),1) internal external internal.*external];
        x(isnan(x)) = 0;
        
        y = data_pile_flat(rows_of_interest,5);
        
        resampled_inds = resample_to_uniform(y);
        x = x(resampled_inds,:);
        y = y(resampled_inds);
        
        b(oi,:) = regress(y,x);
    end
    
    figure('color','white')
    for oi = 1:num_situation_objects
        rows_of_interest = eq( oi, data_pile_flat(:,1));
        internal = data_pile_flat(rows_of_interest,2);
        external = external_support(rows_of_interest);
        x = [ ones(length(internal),1) internal external internal.*external];
        x(isnan(x)) = 0;
        
        y_predicted = x * b(oi,:)';
        y_actual = data_pile_flat(rows_of_interest,5);
        
        subplot(1,num_situation_objects,oi)
        plot( y_actual, y_predicted,'.','MarkerSize', .1)
        
        xlabel('IOU actual');
        ylabel('IOU predicted (new total support)');
        title(situation_objects{oi});
        xlim([0 1]);
        ylim([-.1 1.1]);
        hold on;
        plot([0 1],[0 1],'red');
        hold off;
        
        R=corrcoef(y_actual,y_predicted);
        legend(['r^2: ' num2str(R(1,2))]);
    end
    
    figure('color','white')
    for oi = 1:num_situation_objects
        rows_of_interest = eq( oi, data_pile_flat(:,1));
        internal = data_pile_flat(rows_of_interest,2);
        external = external_support(rows_of_interest);
        x = [ ones(length(internal),1) internal external internal.*external];
        x(isnan(x)) = 0;
        
        y_predicted = x * b(oi,:)';
        y_actual = data_pile_flat(rows_of_interest,5);
        
        subplot(1,num_situation_objects,oi)
        plot( y_actual, x(:,2),'.','MarkerSize', .1)
        
        xlabel('IOU actual');
        ylabel('IOU predicted (old total support)');
        title(situation_objects{oi});
        xlim([0 1]);
        ylim([-.1 1.1]);
        hold on;
        plot([0 1],[0 1],'red');
        hold off;
        
        R=corrcoef(y_actual,x(:,2));
        legend(['r^2: ' num2str(R(1,2))]);
    end
    
    
    
end




