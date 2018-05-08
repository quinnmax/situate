
function [] = grounding_and_retrieval( input, varargin )

% grounding_and_retrieval( directory_containing_results_mats );
% grounding_and_retrieval( results_mat_file_name );
% grounding_and_retrieval( cell_array_of_directories_and_or_mat_file_names );
% grounding_and_retrieval( ..., [additional_results_directory] )
%
% figures will be saved to a results directory. to keep them open, include the flag '-ko'
%
% using the additional_results_directory
%   [additional_results_directory]/[situation_description]/[object_name]/[image_name.csv]
%   format: 
%       x,y,w,h,confidence,(round_truth_intersection_over_union/or -1) \n



    %% process the input, get cell of mat file names 

    if isfile(input) 
        input = { input };
    end
    
    if ischar(input) && isdir(input)
        input = { input };
    end
        
    if iscellstr( input )
        % combination of multiple file names and/or directories
        mat_file_names = {};
        mat_inds = find( cellfun( @isfile, input ) );
        dir_inds = find( cellfun( @isdir, input  ) );
        for di = 1:length(dir_inds)
            temp = dir(fullfile(input{dir_inds(di)}, '*.mat'));
            names = {temp.name};
            names = setsub( names, 'results_grounding.mat');
            names = setsub( names, 'results_retrieval.mat');
            mat_file_names(end+1:end+length(names)) = cellfun( @(x) fullfile( input{dir_inds(di)}, x ), names, 'UniformOutput', false );
        end
        mat_file_names(end+1:end+length(mat_inds)) = input(mat_inds);
        if ~isempty(setsub( 1:length(input), [mat_inds, dir_inds] ))
            error(['specified inputs were not found']);
        end 
    else
        error('should be a mat file, a directory, or a cellstr');
    end

    % get everyone on relative path footing if we can
    for mi = 1:length(mat_file_names)
        if strcmp( pwd, mat_file_names{mi}(1:length(pwd)) )
            mat_file_names{mi} = mat_file_names{mi}(length(pwd)+2:end);
        end
    end

    % deal with varargin
    keep_figs_open = false;
    additional_results_directory = [];
    if ~isempty( varargin )
        if any(strcmp('-ko', varargin ) )
            varargin(strcmp('-ko', varargin )) = [];
            keep_figs_open = true;
        end
    end
    
    if ~isempty( varargin ) && ischar(varargin{1}) && isdir(varargin{1})
        additional_results_directory = varargin{1}; 
    end


    %% group on condition 

        condition_structs_unique = {};
        condition_struct_assignments = zeros(1,length(mat_file_names));
        raw_descriptions = cell(1,length(mat_file_names));
        for fi = 1:length(mat_file_names)
            temp = load( mat_file_names{fi}, 'p_condition' );
            cur_condition = temp.p_condition;
            raw_descriptions{fi} = cur_condition.description;
            % ignore these fields for purposes of grouping conditions
            cur_condition.seed_test   = [];
            cur_condition.description = [];

            cur_condition_assignment = find( cellfun( @(x) isequal_struct( cur_condition, x ), condition_structs_unique ) );
            if isempty(cur_condition_assignment)
                condition_structs_unique{end+1}  = cur_condition;
                condition_struct_assignments(fi) = length(condition_structs_unique);
            else
                condition_struct_assignments(fi) = cur_condition_assignment;
            end
        end
        num_conditions = length(condition_structs_unique);

        % give descriptions back
        for ci = 1:num_conditions
            condition_structs_unique{ci}.description = raw_descriptions{ find(eq(ci,condition_struct_assignments),1,'first') };
        end
        
        descriptions = cellfun( @(x) x.description, condition_structs_unique, 'UniformOutput', false );
        descriptions = cellfun( @(x) fileparts_mq(x,'name'), descriptions, 'UniformOutput', false );
        descriptions = cellfun( @(x) strrep( x, '_', ' ' ), descriptions, 'UniformOutput', false );
        descriptions = cellfun( @(x) strrep( x, '.json', '' ),  descriptions, 'UniformOutput', false );
        descriptions = cellfun( @(x) strrep( x, 'parameters', '' ),  descriptions, 'UniformOutput', false );
        descriptions = cellfun( @strtrim, descriptions, 'UniformOutput', false );

        % make sure everyone is looking for the same situation
        situation_struct = [];

        situation_objects = cellfun( @(x) x.situation_objects, condition_structs_unique, 'UniformOutput', false );
        assert( all( cellfun( @(x) isequal( situation_objects{1}, x), situation_objects(2:end) ) ) );
        situation_objects = situation_objects{1};
        situation_struct.situation_objects = situation_objects;

        situation_description = cellfun( @(x) x.situation_description, condition_structs_unique, 'UniformOutput', false );
        assert( all( cellfun( @(x) isequal( situation_description{1}, x), situation_description(2:end) ) ) );
        situation_description = situation_description{1};
        situation_struct.situation_description = situation_description;

        situation_struct.situation_objects_possible_labels = condition_structs_unique{1}.situation_objects_possible_labels;

        num_situation_objects = length(situation_struct.situation_objects);



    %% generate a results directory, if necessary 

        % see if they share a results directory already
        if all( strcmp( fileparts(mat_file_names{1}), cellfun( @fileparts, mat_file_names(2:end), 'UniformOutput', false ) ) )
            results_directory = fileparts(mat_file_names{1});
        else
            % make a new results directory name
            results_directory = sprintf('results/combined_results_%s/', datestr(now,'yyyy.mm.dd.HH.MM.SS') );
            % make a new results directory
            mkdir(results_directory);
            % generate a list of mat files used, put file in new directory
            % send a message to the console
        end



    %% data work 

        % get fnames
            im_fnames = cell(1,num_conditions);
            for ci = 1:num_conditions
                cur_mat_fnames = mat_file_names(eq(ci,condition_struct_assignments));
                temp = cellfun( @(x) load( x,'fnames_im_test'), cur_mat_fnames );
                im_fnames{ci} = vertcat(temp.fnames_im_test);
            end
            try
                assert( all( cellfun( @(x) isequal( im_fnames{1}, x), im_fnames(2:end) ) ) );
            catch
                error('looks like not all conditions ran the same images');
            end
            im_fnames = im_fnames{1};
            lb_fnames = cellfun( @(x) [fileparts_mq(x, 'path/name') '.json'], im_fnames, 'UniformOutput', false );
            lb_exists = cellfun( @(x) exist( x, 'file' ), lb_fnames );
            lb_fnames( ~lb_exists ) = cell(1,sum(~lb_exists)); % not deleting, just leaving empty
        
        % check for un-run workspaces, make sure they still all match
            workspaces_final = cell( 1, num_conditions );
            workspace_ran = cell(1,num_conditions);
            for ci = 1:num_conditions
                cur_mat_fnames = mat_file_names(eq(ci,condition_struct_assignments));
                temp = cellfun( @(x) load( x, 'workspaces_final'), cur_mat_fnames );
                workspaces_final{ci} = [temp.workspaces_final];
                workspace_ran{ci} = cellfun( @(x) ~isempty(x), workspaces_final{ci} );
            end
            try
                assert( all( cellfun( @(x) isequal( workspace_ran{1}, x), workspace_ran(2:end) ) ) );
            catch
                error('looks like which images were run does not match for each condition');
            end
            workspace_ran = workspace_ran{1};
            im_fnames = im_fnames(workspace_ran);
            lb_fnames = lb_fnames(workspace_ran);
            num_images = sum(workspace_ran);
            for ci = 1:num_conditions
                workspaces_final{ci}(~workspace_ran) = [];
                workspaces_final{ci} = [workspaces_final{ci}{:}];
            end
            
        % get pos/neg assignment (based on presense of label file) for each image
        % (not doing it per condition because we've asserted the same image file list for all conditions)
            %is_situation_instance = cellfun( @(x) exist([fileparts_mq(x,'path/name'),'.json'],'file') |  exist([fileparts_mq(x,'path/name'),'.labl'],'file'), im_fnames );
            label_structs = situate.labl_load( lb_fnames, situation_struct );
            if isstruct(label_structs), label_structs = mat2cell(label_structs, ones(1,size(label_structs,1)),ones(1,size(label_structs,2))); end
            is_situation_instance = cellfun( @(x) ~isempty(x), label_structs );
            is_situation_instance = reshape( is_situation_instance, [], 1 );
            for li = 1:length(label_structs)
                if ~isempty( label_structs{li} ) ...
                && isempty( setsub( situation_objects, label_structs{li}.labels_adjusted ) )
                    is_situation_instance(li) = true;
                end
            end
      
        % rescore workspaces (account for objects of the same type that are arbitrarily assigned a number)
            for ci = 1:num_conditions
                for imi = 1:num_images
                    workspaces_final{ci}(imi) = situate.workspace_score( workspaces_final{ci}(imi), label_structs{imi}, condition_structs_unique{ci} );
                end
            end

        % final IOUs for objects
        % final internal support for objects
        % final external support for objects
        % final total    support for objects
            final_ious             = cell(1,num_conditions);
            final_support_internal = cell(1,num_conditions);
            final_support_external = cell(1,num_conditions);
            final_support_total    = cell(1,num_conditions);
            final_support_full_situation = cell(1,num_conditions);
            for ci  = 1:num_conditions
                final_ious{ci}             = zeros( num_images, num_situation_objects );
                final_support_internal{ci} = zeros( num_images, num_situation_objects );
                final_support_external{ci} = zeros( num_images, num_situation_objects );
                final_support_total{ci}    = zeros( num_images, num_situation_objects );
                final_support_full_situation{ci} = zeros( num_images, 1 );
                for imi = 1:num_images
                    final_support_full_situation{ci}(imi) = workspaces_final{ci}(imi).situation_support;
                    for oi  = 1:num_situation_objects
                        wi = strcmp( situation_struct.situation_objects{oi}, workspaces_final{ci}(imi).labels);
                        if any(wi)
                            final_ious{ci}(imi,oi)             = workspaces_final{ci}(imi).GT_IOU(wi);
                            final_support_internal{ci}(imi,oi) = workspaces_final{ci}(imi).internal_support(wi);
                            final_support_external{ci}(imi,oi) = workspaces_final{ci}(imi).external_support(wi);
                            final_support_total{ci}(imi,oi)    = workspaces_final{ci}(imi).total_support(wi);
                        else
                            % object wasn't represented in the final workspaces, so it gets Nan
                            final_ious{ci}(imi,oi)             = nan;
                            final_support_internal{ci}(imi,oi) = nan;
                            final_support_external{ci}(imi,oi) = nan;
                            final_support_total{ci}(imi,oi)    = nan;
                        end
                    end
                end
            end



    %% load additional results from external folder 

        if ~isempty( additional_results_directory )

            need_to_make_workspaces_from_external_boxes = true;
            
            if exist( fullfile( additional_results_directory, 'processed_box_data.mat'), 'file' )

                data_fname = situate.check_for_existing_model(additional_results_directory,'im_fnames',im_fnames);
                
                if ~isempty(data_fname)
                    
                    additional_results = load( data_fname );
                    display([ 'loaded addtional results from : ' data_fname ]);
                    need_to_make_workspaces_from_external_boxes = false;
                    
                    % sort the data in the additional results so they are consistent with the
                    % ordering we have now
                    [~,order_a]     = sort(im_fnames);
                    [~,order_a_inv] = sort(order_a);
                    [~,order_b]     = sort(additional_results.im_fnames);
                    
                    additional_results.im_fnames = additional_results.im_fnames(order_b( order_a_inv ));
                    additional_results.lb_fnames = additional_results.lb_fnames(order_b( order_a_inv ));
                    additional_results.workspaces_final = additional_results.workspaces_final(order_b(order_a_inv));
                    
                end
                
            end
                    
            if need_to_make_workspaces_from_external_boxes

                additional_results = [];
                additional_results.im_fnames = im_fnames;
                additional_results.lb_fnames = lb_fnames;
                additional_results.situation_struct = situation_struct;
                
                for imi = 1:num_images

                    im_fname = im_fnames{imi};
                    additional_results.workspaces_final(imi) = csvs2workspace( additional_results_directory, im_fname, situation_struct  );

                    additional_results.workspaces_final(imi) = ...
                        situate.workspace_score( ...
                            additional_results.workspaces_final(imi), ...
                            additional_results.lb_fnames{imi}, ...
                            additional_results.situation_struct );

                    additional_results.workspaces_final(imi).iteration = 0;

                    progress(imi,num_images,['processing boxes loaded from ' additional_results_directory]);

                end

                save( fullfile( additional_results_directory, 'processed_box_data.mat'), '-struct', 'additional_results' );
                
            end

            num_conditions = num_conditions + 1;

            final_ious{num_conditions}                   = vertcat(additional_results.workspaces_final.GT_IOU);
            final_support_internal{num_conditions}       = vertcat(additional_results.workspaces_final.total_support);
            final_support_external{num_conditions}       = zeros( num_images, num_situation_objects );
            final_support_total{num_conditions}          = vertcat(additional_results.workspaces_final.total_support);
            final_support_full_situation{num_conditions} = vertcat( additional_results.workspaces_final.situation_support );
            workspaces_final{num_conditions}             = additional_results.workspaces_final;

            condition_structs_unique{num_conditions}.description = additional_results_directory;
            condition_structs_unique{num_conditions}.num_iterations = nan;
            condition_structs_unique{num_conditions}.situation_objects = situation_objects;
            
            temp = additional_results_directory;
            if strcmp( temp(end), filesep ), temp = temp(1:end-1); end
            descriptions{num_conditions} = last(strsplit(temp,filesep));

        end

      


    %% grounding analysis 

        % detections at various IOU thresholds
            num_thresholds = 10;
            iou_thresholds = sort(unique([linspace(0,1,num_thresholds+1) .5])); % make sure .5 is in there
            iou_thresholds = iou_thresholds(2:end);
            num_thresholds = length(iou_thresholds);

            object_detections_at_iou_true_pos  = cell(1,num_conditions);
            object_detections_at_iou_false_pos = cell(1,num_conditions);
            object_detections_at_iou_true_neg  = cell(1,num_conditions);
            object_detections_at_iou_false_neg = cell(1,num_conditions);

            full_situation_detections_at_iou_true_pos  = cell(1,num_conditions);
            full_situation_detections_at_iou_false_pos = cell(1,num_conditions);
            full_situation_detections_at_iou_true_neg  = cell(1,num_conditions);
            full_situation_detections_at_iou_false_neg = cell(1,num_conditions);

            detection_iteration = cell(1,num_conditions);

            for ci = 1:num_conditions

                object_detections_at_iou_true_pos{ci}  = nan( num_images, num_thresholds, num_situation_objects);
                object_detections_at_iou_false_pos{ci} = nan( num_images, num_thresholds, num_situation_objects);
                object_detections_at_iou_true_neg{ci}  = nan( num_images, num_thresholds, num_situation_objects);
                object_detections_at_iou_false_neg{ci} = nan( num_images, num_thresholds, num_situation_objects);

                full_situation_detections_at_iou_true_pos{ci}  = nan( num_images, num_thresholds );
                full_situation_detections_at_iou_false_pos{ci} = nan( num_images, num_thresholds );
                full_situation_detections_at_iou_true_neg{ci}  = nan( num_images, num_thresholds );
                full_situation_detections_at_iou_false_neg{ci} = nan( num_images, num_thresholds );

                detection_iteration{ci} = nan( num_images, num_thresholds );

                for ti = 1:num_thresholds

                    for oi = 1:num_situation_objects

                        object_detections_at_iou_true_pos{ci}(:,ti,oi) = ...
                                 is_situation_instance ...
                               & final_ious{ci}(:,oi) >= iou_thresholds(ti) ...
                               & final_support_total{ci}(:,oi) >= iou_thresholds(ti);

                        object_detections_at_iou_false_pos{ci}(:,ti,oi) = ...
                                ~is_situation_instance ...
                               & final_support_total{ci}(:,oi) >= iou_thresholds(ti);

                        object_detections_at_iou_true_neg{ci}(:,ti,oi) = ...
                                ~is_situation_instance ...
                               & final_support_total{ci}(:,oi) < iou_thresholds(ti);

                        object_detections_at_iou_false_neg{ci}(:,ti,oi) = ...
                                 is_situation_instance ...
                               & final_support_total{ci}(:,oi) < iou_thresholds(ti);

                    end

                    full_situation_detections_at_iou_true_pos{ci}(:,ti) = ...
                             is_situation_instance ...
                           & all( final_ious{ci} >= iou_thresholds(:,ti), 2 ) ...
                           & all( final_support_total{ci} >= iou_thresholds(ti), 2 );

                    full_situation_detections_at_iou_false_pos{ci}(:,ti) = ...
                            ~is_situation_instance ...
                           & all( final_support_total{ci} >= iou_thresholds(ti), 2 );

                    full_situation_detections_at_iou_true_neg{ci}(:,ti) = ...
                            ~is_situation_instance ...
                           & any( final_support_total{ci} < iou_thresholds(ti), 2 );    

                    full_situation_detections_at_iou_false_neg{ci}(:,ti) = ...
                             is_situation_instance ... 
                           & any( final_support_total{ci} < iou_thresholds(ti), 2 );

                    stop_times = [workspaces_final{ci}.iteration];
                    detection_inds = logical( full_situation_detections_at_iou_true_pos{ci}(:,ti) );
                    detection_iteration{ci}(detection_inds,ti) = stop_times(detection_inds);

                end


            end

            % save off results

            results_struct_grounding = [];

            results_struct_grounding.mat_file_names             = mat_file_names;
            results_struct_grounding.condition_structs_unique	= condition_structs_unique;
            results_struct_grounding.situation_objects          = situation_objects;
            results_struct_grounding.im_fnames                  = im_fnames;

            results_struct_grounding.final_ious               = final_ious;
            results_struct_grounding.final_support_internal	= final_support_internal;
            results_struct_grounding.final_support_external   = final_support_external;
            results_struct_grounding.final_support_total      = final_support_total;

            results_struct_grounding.final_support_full_situation = final_support_full_situation;

            results_struct_grounding.is_situation_instance	= is_situation_instance;
            results_struct_grounding.iou_thresholds			= iou_thresholds;

            results_struct_grounding.object_detections_at_iou_true_pos            = object_detections_at_iou_true_pos;
            results_struct_grounding.object_detections_at_iou_false_pos           = object_detections_at_iou_false_pos;
            results_struct_grounding.object_detections_at_iou_true_neg            = object_detections_at_iou_true_neg;
            results_struct_grounding.object_detections_at_iou_false_neg           = object_detections_at_iou_false_neg;

            results_struct_grounding.full_situation_detections_at_iou_true_pos    = full_situation_detections_at_iou_true_pos;
            results_struct_grounding.full_situation_detections_at_iou_false_pos   = full_situation_detections_at_iou_false_pos;
            results_struct_grounding.full_situation_detections_at_iou_true_neg    = full_situation_detections_at_iou_true_neg;
            results_struct_grounding.full_situation_detections_at_iou_false_neg   = full_situation_detections_at_iou_false_neg;

            save( fullfile(results_directory, ['results_grounding.mat']), '-struct', 'results_struct_grounding' );



    %% retrieval analysis 

        inds_pos = find(  is_situation_instance );
        inds_neg = ~is_situation_instance;
        num_images_neg = sum(inds_neg);
        num_images_pos = sum(is_situation_instance);
        rank     = cell(1,num_conditions);
        for ci = 1:num_conditions
            rank{ci} = zeros(length(inds_pos),1);
            for ii = 1:length(inds_pos)
                cur_pos_ind = inds_pos(ii);
                cur_pos_val = final_support_full_situation{ci}(cur_pos_ind);
                % place the pos in front
                cur_situation_support_vals = [cur_pos_val; final_support_full_situation{ci}(inds_neg)];
                % sort
                [~,support_vals_sort_order] = sort( cur_situation_support_vals, 'descend' );
                % see where 1 went
                rank{ci}(ii) = find( eq( support_vals_sort_order, 1 ) );
            end
        end

        
        
        % ROC analysis
        AUROC = nan( 1,num_conditions);
        FPR   = cell(1,num_conditions);
        TPR   = cell(1,num_conditions);
        for ci = 1:num_conditions
            [AUROC(ci), TPR{ci}, FPR{ci}] = ROC( final_support_full_situation{ci}, is_situation_instance );
        end
        
        
        
        % PR analysis
        precision = cell(1,num_conditions);
        recall    = cell(1,num_conditions);
        for ci = 1:num_conditions
           [precision{ci}, recall{ci}] = PR_analysis( final_support_full_situation{ci}, is_situation_instance );
        end
        
        
        
        % recall @ n (an un-normalized ROC-type analysis)
        recall_at_n = cell(1,num_conditions);
        for ci = 1:num_conditions
            recall_at_n{ci} = arrayfun( @(x) sum( rank{ci} <= x ), 1:num_images_neg ) ./ num_images_pos;
        end
        
        
        
        % save results

        results_struct_retrieval = [];

        results_struct_retrieval.mat_file_names             = mat_file_names;
        results_struct_retrieval.condition_structs_unique	= condition_structs_unique;
        results_struct_retrieval.situation_objects          = situation_objects;
        results_struct_retrieval.im_fnames                  = im_fnames;

        results_struct_retrieval.rank = rank;
        results_struct_retrieval.mean_rank = cellfun( @mean, rank );
        results_struct_retrieval.median_rank = cellfun( @median, rank );

        results_struct_retrieval.recall_at_n = recall_at_n;
        
        results_struct_retrieval.FPR   = FPR;
        results_struct_retrieval.TPR   = TPR;
        results_struct_retrieval.AUROC = AUROC;
        
        results_struct_retrieval.precision = precision;
        results_struct_retrieval.recall    = recall;

        save( fullfile(results_directory, ['results_retrieval.mat']), '-struct', 'results_struct_retrieval' );
        for ci = 1:num_conditions
            csvwrite( fullfile(results_directory, ['recall_at_n_' descriptions{ci} '.csv']), recall_at_n{ci} )
        end



    %% visualize 

        % visualize grounding
        linespec = {'k-','k--','k:','k-.','k-o','k--o','k:o','k-.o'};

        % successful groundings 
        %   x axis, threshold
        %   y axis, count
        %   lines per parameterization
        %   subplot per object type, full situation

        num_pos_images = sum( is_situation_instance );

        if any(is_situation_instance)

            fig_title = 'object grounding quality';
            h = figure('color','white','Name',fig_title,'position',[720 2 300*(num_situation_objects+1) 400]);

            for oi = 1:num_situation_objects
                subplot2(1,num_situation_objects+1,1,oi);
                for ci = 1:num_conditions
                    plot( iou_thresholds, sum( object_detections_at_iou_true_pos{ci}(:,:,oi), 1 ), linespec{ci} );
                    hold on;
                end
                title( situation_objects{oi});
                xlabel('IOU thresholds');
                ylabel('detection count');
                xlim([0 1]);
                ylim([0 1.05*num_pos_images]);
            end

            subplot2(1,num_situation_objects+1,1,num_situation_objects+1);
            for ci = 1:num_conditions
                plot( iou_thresholds, sum(full_situation_detections_at_iou_true_pos{ci},1), linespec{ci} );
                hold on;
            end
            title( 'full situation' );
            xlabel('IOU thresholds');
            ylabel('detection count');
            xlim([0 1]);
            ylim([0 1.05*num_pos_images]);

            for bi = 1:num_situation_objects + 1
                subplot2(1,num_situation_objects+1,1,bi);
                plot([.5 .5],[0 num_pos_images],'--','Color',[.75 .75 .75]);
                plot([0 1],[num_pos_images num_pos_images], '--','Color',[.75 .75 .75]);
            end
            legend(descriptions, 'Location', 'northeast' );

            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
            
        end

            
            
        % detections over iteration
        %   x axis, iteration
        %   y axis, cummulative full detections
        %   lines, conditions
        if any(is_situation_instance)

            fig_title = 'detections over iteration';
            h = figure('color','white','Name',fig_title,'position',[720 2 500 400]);
            x = 1:max(cellfun( @(x) x.num_iterations, condition_structs_unique ));
            for ci = 1:num_conditions
                y = arrayfun( @(x) sum( detection_iteration{ci}(:,5) < x ), x );
                plot( x,y, linespec{ci} );
                hold on;
            end
            plot( x,repmat(num_pos_images,1,length(x)), '--','Color',[.75 .75 .75] );
            legend( descriptions, 'Location', 'northeast');
            ylim([1 1.1*num_pos_images])
            xlabel('iteration');
            ylabel({'situation detections','(cumulative)'})
            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
            
        end

            
            
        % visualize retrieval results
        if any(is_situation_instance) && any(~is_situation_instance)
            fig_title = 'retrieval results';
            h = figure('color','white','Name',fig_title,'position',[720 2 400*num_conditions 400]);

            max_y = 0;
            all_ranks = [results_struct_retrieval.rank{:}];
            upper_rank = prctile( all_ranks(:), 95 );
            bins = 10;
            for ci = 1:num_conditions
                subplot(1,num_conditions,ci);
                hist( results_struct_retrieval.rank{ci}, linspace(0,upper_rank,bins) );
                n = hist( results_struct_retrieval.rank{ci}, linspace(0,upper_rank,bins) );
                if max(n) > max_y, max_y = max(n); end
                title( descriptions{ci} );
                xlabel('positive image rank');
                ylabel('count');
            end
            for ci = 1:num_conditions
                subplot(1,num_conditions,ci)
                xlim([0-upper_rank/bins upper_rank+upper_rank/bins]);
                ylim([0 max(1,max_y*1.1)]);
                text( .6*upper_rank, max(1,max_y*1.1)*.95, ['median rank: ' num2str(results_struct_retrieval.median_rank(ci))] );
            end

            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
        end



        % support histograms
            fig_title = 'support histograms';
            h = figure('color','white','Name',fig_title,'position',[720 2 900 600]);

            for ci = 1:num_conditions
                subplot2(num_conditions, 2, ci, 1);
                hist( final_support_full_situation{ci}(is_situation_instance) );
                ylabel( {descriptions{ci};'count'} );
                xlim([-.1,1.1])
                xlabel('situation support score');
                title('positives');

                subplot2(num_conditions, 2, ci, 2);
                hist( final_support_full_situation{ci}(~is_situation_instance) );
                xlim([-.1,1.1])
                xlabel('situation support score');
                ylabel('count');
                title('negatives');
            end

            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end


            
        % roc analysis
        if any(is_situation_instance) && any(~is_situation_instance)

            fig_title = ['ROC curves'];
            h = figure('color','white','Name',fig_title,'position',[720 2 500 400]);

            temp = descriptions;

            for ci = 1:num_conditions
                plot(results_struct_retrieval.FPR{ci}, results_struct_retrieval.TPR{ci},linespec{ci} );
                hold on;
                temp{ci} = [temp{ci} ', AUROC: ' num2str(results_struct_retrieval.AUROC(ci))];
            end
            legend( temp, 'Location', 'southeast' );
            xlabel('FPR')
            ylabel('TPR');
            
            xlim([0 1]);
            ylim([0 1]);

            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
        end
        
        
        % PR curves
        if any(is_situation_instance) && any(~is_situation_instance)

            fig_title = ['PR curves'];
            h = figure('color','white','Name',fig_title,'position',[720 2 500 400]);

            temp = descriptions;

            for ci = 1:num_conditions
                plot(results_struct_retrieval.recall{ci}, results_struct_retrieval.precision{ci},linespec{ci} );
                hold on;
            end
            legend( temp, 'Location', 'southwest' );
            xlabel('recall')
            ylabel('precision');
            
            xlim([0 1]);
            ylim([0 1]);

            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
        end


            
        % recall @ n
        if any(is_situation_instance) && any(~is_situation_instance)
            fig_title = 'recall at n';
            h = figure('color','white','Name',fig_title,'position',[720 2 500 400]);
            
            for ci = 1:num_conditions
                plot( 1:num_images_neg, recall_at_n{ci}, linespec{ci} );
                hold on;
            end
            xlabel('number of images returned')
            ylabel('recall')
            legend(descriptions);
            
            saveas(h,fullfile(results_directory,fig_title),'png');
            if ~keep_figs_open, close(h); end
        end
            
            
            
        % pos images
        num_examples = 4;
        if any(is_situation_instance)
            num_examples_pos = min( num_examples, num_images_pos );
            for ci = 1:num_conditions

                [~,sort_order_high] = sort( final_support_full_situation{ci}, 'descend' );
                [~,sort_order_low]  = sort( final_support_full_situation{ci}, 'ascend'  );
                % remove neg instances
                sort_order_high_pos = setsub( sort_order_high, find(~is_situation_instance ) );
                sort_order_low_pos  = setsub( sort_order_low,  find(~is_situation_instance ) );

                fig_title = ['high low support, positive instances, ' descriptions{ci}];
                h = figure('color','white','Name',fig_title,'position',[720 2 1400 600]);

                for imi = 1:num_examples_pos
                    subplot2(2,num_examples_pos,1,imi);
                    cur_ind = sort_order_high_pos(imi);
                    situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                    xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                    if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'positive instances','high support')); end

                    subplot2(2,num_examples_pos,2,imi);
                    cur_ind = sort_order_low_pos(imi);
                    situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                    xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                    if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'positive instances','low support')); end
                end

                saveas(h,fullfile(results_directory,fig_title),'png');
                if ~keep_figs_open, close(h); end

            end
        end

            
            
        % neg images
        num_examples_neg = min( num_examples, sum(~is_situation_instance) );
        if any( ~is_situation_instance )
            for ci = 1:num_conditions

                [~,sort_order_high] = sort( final_support_full_situation{ci}, 'descend' );
                [~,sort_order_low]  = sort( final_support_full_situation{ci}, 'ascend'  );
                % remove pos instances
                sort_order_high_neg = setsub( sort_order_high, find(is_situation_instance ) );
                sort_order_low_neg  = setsub( sort_order_low,  find(is_situation_instance ) );

                fig_title = ['high low support, negative instances, ' descriptions{ci}];
                h = figure('color','white','Name',fig_title,'position',[720 2 1400 600]);

                for imi = 1:num_examples_neg
                    subplot2(2,num_examples_neg,1,imi);
                    cur_ind = sort_order_high_neg(imi);
                    situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                    xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                    if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'negative instances','high support')); end

                    subplot2(2,num_examples_neg,2,imi);
                    cur_ind = sort_order_low_neg(imi);
                    situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                    xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                    if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'negative instances','low support')); end
                end

                saveas(h,fullfile(results_directory,fig_title),'png');
                if ~keep_figs_open, close(h); end

            end
        end



    %% expensive analysis stuff (first iteration over threshold, generally good for in-depth stuff) 

            do_the_expensive_analysis = false;
            if do_the_expensive_analysis

                iter_over_thresh = cell( 1, num_conditions );
                iou_thresholds = [];
                for ci = 1:num_conditions
                    cur_condition_mat_fnames = mat_file_names(eq(condition_struct_assignments,ci));
                    [iter_over_thresh{ci}, ~, iou_thresholds] = first_iteration_over_threshold( cur_condition_mat_fnames );
                end

            end  



end













