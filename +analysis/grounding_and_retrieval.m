
function [] = grounding_and_retrieval( input, varargin )

% grounding_and_retrieval( directory_containing_results_mats );
% grounding_and_retrieval( results_mat_file_name );
% grounding_and_retrieval( cell_of_results_mat_fnames );
% grounding_and_retrieval( cell_of_results_directories );
% grounding_and_retrieval( cell_of_results_directories_and_mat_fnames );
% grounding_and_retrieval( ..., [additional_results_directory] )
%
% additional_results_directory
%   format:



    %% process the input, get cell of mat file names 


    if ~exist('input','var') || isempty(input)
        % input = {'/Users/Max/Dropbox/Projects/situate/results/dogwalking_positives_test_2018.03.27.23.28.01/parameters_situate_w_pool_priming_fold_01_2018.03.28.00.45.43.mat'};

        % input = {'/Users/Max/Dropbox/Projects/situate/results/dogwalking_negatives_check_2018.03.28.08.12.24'};

        %input = {'/Users/Max/Dropbox/Projects/situate/results/dogwalking_positives_test_2018.03.27.23.28.01/parameters_situate_w_pool_priming_fold_01_2018.03.28.00.45.43.mat'; ...
        %         '/Users/Max/Dropbox/Projects/situate/results/dogwalking_negatives_check_2018.03.28.08.12.24'};

        input = {'/Users/Max/Dropbox/Projects/situate/results/dogwalking_positives_test_2018.03.27.23.28.01/parameters_situate_w_pool_priming_fold_01_2018.03.28.00.45.43.mat'; ...
                 '/Users/Max/Dropbox/Projects/situate/results/dogwalking_negatives_general_2018.03.30.17.52.03'};


        varargin = {'rcnn box data/'};
        warning('using debug directories, not real analysis');

        save_final_workspace_images = false;
    end


        if isfile( input )
            [~,~,ext] = fileparts(input);
            assert( strcmp( ext, '.mat' ) );
            mat_file_names = {input};
        elseif iscellstr( input )
            % combination of multiple file names and/or directories
            mat_file_names = {};
            mat_inds = find( cellfun( @isfile, input ) );
            dir_inds = find( cellfun( @isdir, input  ) );
            for di = 1:length(dir_inds)
                temp = dir(fullfile(input{dir_inds(di)}, '*.mat'));
                mat_file_names(end+1:end+length(temp)) = cellfun( @(x) fullfile( input{dir_inds(di)}, x ), {temp.name}, 'UniformOutput', false );
            end
            mat_file_names(end+1:end+length(mat_inds)) = input(mat_inds);
            if ~isempty(setsub( 1:length(input), [mat_inds, dir_inds] ))
                warning('some specified inputs were not found');
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

        % remove results files that may already be present from previous run
        files_remove = cellfun( @(x) strcmp( fileparts_mq(x,'name.ext'), 'results_grounding.mat' ), mat_file_names ) ...
                     | cellfun( @(x) strcmp( fileparts_mq(x,'name.ext'), 'results_retrieval.mat' ), mat_file_names );
        mat_file_names(files_remove) = [];

        if ~isempty( varargin )
            additional_results_directory = varargin{1};
        else
            additional_results_directory = [];
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

            [cur_condition_assignment, equality_caveats] = find( cellfun( @(x) isequal_struct( cur_condition, x ), condition_structs_unique ) );
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

        % final workspaces by condition
            im_fnames = cell(1,num_conditions);
            for ci = 1:num_conditions
                cur_mat_fnames = mat_file_names(eq(ci,condition_struct_assignments));
                temp = cellfun( @(x) load( x,'fnames_im_test'), cur_mat_fnames );
                im_fnames{ci} = vertcat(temp.fnames_im_test);
            end

        % make sure each condition was applied to the same set of images
            assert( all( cellfun( @(x) isequal( im_fnames{1}, x), im_fnames(2:end) ) ) );
            im_fnames = im_fnames{1};

            lb_fnames = cellfun( @(x) [fileparts_mq(x, 'path/name') '.json'], im_fnames, 'UniformOutput', false );
            lb_exists = cellfun( @(x) exist( x, 'file' ), lb_fnames );
            lb_fnames( ~lb_exists ) = cell(1,sum(~lb_exists)); % not deleting, just leaving empty

        % get pos/neg assignment (based on presense of label file) for each image
        % (not doing it per condition because we've asserted the same image file list for all conditions)
            is_situation_instance = cellfun( @(x) exist([fileparts_mq(x,'path/name'),'.json'],'file') |  exist([fileparts_mq(x,'path/name'),'.labl'],'file'), im_fnames );

        % final workspaces by condition
            workspaces_final = cell( 1, num_conditions );
            for ci = 1:num_conditions
                cur_mat_fnames = mat_file_names(eq(ci,condition_struct_assignments));
                temp = cellfun( @(x) load( x, 'workspaces_final'), cur_mat_fnames );
                workspaces_final{ci} = [temp.workspaces_final];
            end

        % remove un-run workspaces, make sure all conditions still match
            inds_remove_per_condition = cell(1,num_conditions);
            for ci = 1:num_conditions
                inds_remove_per_condition{ci} = cellfun( @isempty, workspaces_final{ci} );
            end
            % if we bonk here, then some conditions weren't run on all methods
            assert( all( cellfun( @(x) isequal( inds_remove_per_condition{1}, x ), inds_remove_per_condition(2:end) ) ) );
            inds_remove = inds_remove_per_condition{1};
            for ci = 1:num_conditions
                workspaces_final{ci}(inds_remove) = [];
                workspaces_final{ci} = [workspaces_final{ci}{:}];
            end
            im_fnames(inds_remove) = [];
            num_images = length( im_fnames );
            is_situation_instance(inds_remove) = [];

        % rescore workspaces (account for objects of the same type that are arbitrarily assigned a number)
            for ci = 1:num_conditions
                for imi = 1:num_images
                    lb_fname = [fileparts_mq( im_fnames{imi}, 'path/name'), '.json'];
                    if exist(lb_fname,'file')
                        workspaces_final{ci}(imi) = situate.workspace_score( workspaces_final{ci}(imi), im_fnames{imi}, condition_structs_unique{ci} );
                    end
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



    %% deal with additional results from external folder 

        if ~isempty( additional_results_directory )

            if exist( fullfile( additional_results_directory, 'processed_box_data.mat'), 'file' )

                additional_results = load( fullfile( additional_results_directory, 'processed_box_data.mat') );
                display([ 'loaded addtional results from : ' fullfile( additional_results_directory, 'processed_box_data.mat') ]);

            else

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

        end

        if save_final_workspace_images
            % for imi = 1:num_images
            for imi = 1:10
                figure();
                subplot(1,2,1);
                situate.workspace_draw( im_fnames{imi}, situation_struct, workspaces_final{num_conditions}(imi) );
                subplot(1,2,2);
                situate.labl_draw( lb_fnames{imi} );
            end
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

        AUROC = nan(1,num_conditions);
        FPR   = cell(1,num_conditions);
        TPR   = cell(1,num_conditions);
        for ci = 1:num_conditions
            [AUROC(ci), TPR{ci}, FPR{ci}] = ROC( final_support_full_situation{ci}, is_situation_instance, 1 );
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

        results_struct_retrieval.FPR = FPR;
        results_struct_retrieval.TPR = TPR;
        results_struct_retrieval.AUROC = AUROC;

        save( fullfile(results_directory, ['results_retrieval.mat']), '-struct', 'results_struct_retrieval' );



    %% visualize 

        % visualize grounding
            linespec = {'k-','k--','k..','k-.'};

            descriptions = cellfun( @(x) x.description, condition_structs_unique, 'UniformOutput', false );
            descriptions = cellfun( @(x) strrep( x, '_', ' ' ), descriptions, 'UniformOutput', false );
            descriptions = cellfun( @(x) strrep( x, '/', '' ),  descriptions, 'UniformOutput', false );
            descriptions = cellfun( @(x) strrep( x, '.json', '' ),  descriptions, 'UniformOutput', false );
            descriptions = cellfun( @(x) strrep( x, 'parameters', '' ),  descriptions, 'UniformOutput', false );
            descriptions = cellfun( @strtrim, descriptions, 'UniformOutput', false );

            % successful groundings 
            %   x axis, threshold
            %   y axis, count
            %   lines per parameterization
            %   subplot per object type, full situation

            num_pos_images = sum( is_situation_instance );

            if num_pos_images > 0

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

                saveas(h,fullfile(results_directory,fig_title),'png')

            end



            % detections over iteration
            %   x axis, iteration
            %   y axis, cummulative full detections
            %   lines, conditions

            if num_pos_images > 0

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
                saveas(h,fullfile(results_directory,fig_title),'png')

            end



        % visualize retrieval results
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

            saveas(h,fullfile(results_directory,fig_title),'png')



        % biggest hits and misses
            fig_title = 'support histograms';
            h = figure('color','white','Name',fig_title,'position',[720 2 900 600]);

            for ci = 1:num_conditions
                subplot2(num_conditions, 2, ci, 1);
                hist( final_support_full_situation{ci}(is_situation_instance) );
                ylabel( descriptions{ci} );
                xlim([-.1,1.1])
                title('positives');

                subplot2(num_conditions, 2, ci, 2);
                hist( final_support_full_situation{ci}(~is_situation_instance) );
                xlim([-.1,1.1])
                title('negatives');
            end

            saveas(h,fullfile(results_directory,fig_title),'png')


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

                saveas(h,fullfile(results_directory,fig_title),'png')
            end


        % pos images
            if any(is_situation_instance)
                num_examples = 4;
                for ci = 1:num_conditions

                    [~,sort_order_high] = sort( final_support_full_situation{ci}, 'descend' );
                    [~,sort_order_low]  = sort( final_support_full_situation{ci}, 'ascend'  );
                    % remove neg instances
                    sort_order_high_pos = setsub( sort_order_high, find(~is_situation_instance ) );
                    sort_order_low_pos  = setsub( sort_order_low,  find(~is_situation_instance ) );

                    fig_title = ['high low support, positive instances, ' descriptions{ci}];
                    h = figure('color','white','Name',fig_title,'position',[720 2 1400 600]);

                    for imi = 1:num_examples
                        subplot2(2,num_examples,1,imi);
                        cur_ind = sort_order_high_pos(imi);
                        situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                        xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                        if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'positive instances','high support')); end

                        subplot2(2,num_examples,2,imi);
                        cur_ind = sort_order_low_pos(imi);
                        situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                        xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                        if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'positive instances','low support')); end
                    end

                    saveas(h,fullfile(results_directory,fig_title),'png')

                end
            end

        % neg images
            if any( ~is_situation_instance )
                num_examples = 4;
                for ci = 1:num_conditions

                    [~,sort_order_high] = sort( final_support_full_situation{ci}, 'descend' );
                    [~,sort_order_low]  = sort( final_support_full_situation{ci}, 'ascend'  );
                    % remove pos instances
                    sort_order_high_neg = setsub( sort_order_high, find(is_situation_instance ) );
                    sort_order_low_neg  = setsub( sort_order_low,  find(is_situation_instance ) );

                    fig_title = ['high low support, negative instances, ' descriptions{ci}];
                    h = figure('color','white','Name',fig_title,'position',[720 2 1400 600]);

                    for imi = 1:num_examples
                        subplot2(2,num_examples,1,imi);
                        cur_ind = sort_order_high_neg(imi);
                        situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                        xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                        if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'negative instances','high support')); end

                        subplot2(2,num_examples,2,imi);
                        cur_ind = sort_order_low_neg(imi);
                        situate.workspace_draw( im_fnames{cur_ind}, condition_structs_unique{ci}, workspaces_final{ci}(cur_ind) );
                        xlabel(sprintf('situation support: %f', final_support_full_situation{ci}(cur_ind)));
                        if imi == 1, ylabel(sprintf('%s\n%s\n%s',descriptions{ci},'negative instances','low support')); end
                    end

                    saveas(h,fullfile(results_directory,fig_title),'png')

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













