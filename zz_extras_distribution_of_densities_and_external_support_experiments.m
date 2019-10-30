function [fname_out] = feature_extractor_bulk_append_densities( fname_in, situation_struct_fname, training_fnames )

% incomplete. basically just a script for now. doesn't actually append density values



p_x = .001; % our prior, based on a low estimate based on localization given our model
p_y = .9; % how much we trust enties in the workspace. should be pretty high 
    


    %% load up pre extracted features

    fname_in = '/Users/Max/Dropbox/Projects/situate/pre_extracted_feature_data/dogwalkerdogleash_cnn_features_and_IOUs2017.10.31.00.47.35.mat';
    situation_struct = situate.situation_struct_load_json('/Users/Max/Dropbox/Projects/situate/situation_definitions/dogwalking.json');
    training_fnames = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/';
    labl_data_temp = situate.labl_load(training_fnames);
    
    d = load(fname_in);
    
    training_im_inds = find( ismember( fileparts_mq(d.fnames,'path/name'), fileparts_mq({labl_data_temp.fname_lb},'path/name') ) );
    training_rows = ismember( d.fname_source_index, training_im_inds );
    
    labl_data_training = [];
    for imii = 1:length(training_im_inds)
        imfname = d.fnames{ training_im_inds(imii) };
        if isempty(labl_data_training)
            labl_data_training = situate.labl_load(imfname, situation_struct);
            labl_data_training = repmat(labl_data_training,length(training_im_inds),1);
        else
            labl_data_training(imii) = situate.labl_load(imfname, situation_struct);
        end
    end
    
    normal_dist_model_prior = situation_models.normal_fit( situation_struct, {labl_data_training.fname_lb} );
  
    uniform_dist_model_prior = situation_models.uniform_fit( situation_struct,  {labl_data_training.fname_lb} );
    
    
    num_images = length(training_im_inds);
    num_samples_per_image = 1000;
    num_objs = numel(situation_struct.situation_objects);
    num_params_per_obj = numel(normal_dist_model_prior.mu) / num_objs;
    
   
    gt_iou = d.IOUs_with_each_gt_obj;
    
    
    
    
%% resample from model for each training image to append IOU values, then re-model
% 
%     
%     resampled_big_vector = nan(...
%                             num_images * num_samples_per_image, ...
%                             numel(normal_dist_model_prior.mu) + numel(normal_dist_model_prior.situation_objects));
%     
%     ious_big = [];
%                         
%     for imii = 1:num_images
%         
%         % sample big vect
%         
%         row_description = {'r0' 'rc' 'rf' 'c0' 'cc' 'cf' 'log w' 'log h' 'log aspect ratio' 'log area ratio'}; 
%         % per obj, in obj order from situation struct
%         samples = mvnrnd( normal_dist_model_prior.mu, normal_dist_model_prior.Sigma, num_samples_per_image);
%       
%         ious = nan( size(samples,1),num_objs);
%         for oi = 1:num_objs
%             
%             % get gt box for this image/object
%             wi = find( strcmp( labl_data_training(imii).labels_adjusted, situation_struct.situation_objects{oi} ), 1 );
%             box_data = labl_data_training(imii).boxes_normalized_r0rfc0cf(wi,:);
%             
%             % get sampled params for this obj
%             param_inds = (oi-1)*numel(row_description) + [1,3,4,6];
%             sampled_box_data = samples(:,param_inds);
%            
%             % calc ious
%             ious(:,oi) = intersection_over_union_continuous( sampled_box_data, box_data,'r0rfc0cf','r0rfc0cf' );
% 
%         end
%         
%         ious_big = [ious_big; ious];
%         
%         %resampled_big_vector( (imii-1) * num_samples_per_image+1 : imii * num_samples_per_image, : ) = [ samples ious ];
%         
%         for oi = 1:num_objs
%             r0a = (imii-1) * num_samples_per_image+1;
%             rfa = imii * num_samples_per_image;
%             c0a = (oi-1)*(num_params_per_obj+1)+1;
%             cfa = oi*(num_params_per_obj+1);
%             
%             c0b = (oi-1)*num_params_per_obj+1;
%             cfb = oi*num_params_per_obj;
%             resampled_big_vector( r0a : rfa, c0a : cfa) = [samples(:,c0b:cfb) ious(:,oi)];
%         end
%             
%         progress(imii,num_images);
%         
%     end
%     
%     % just visualize the distribution of IOUs when sampling from the situation model
%     
%     figure('color','white');
%     for oi = 1:3
%         subplot(1,3,oi);
%         temp_x = ious_big(:,oi);
%         temp_y = cdf_emp(ious_big(:,oi));
%         plot(temp_x,temp_y,'.'); 
%         hold on;
%         iou50val = temp_y( argmin( abs( temp_x-.5) ) );
%         plot([.5 .5],[0 iou50val],'r');
%         plot([0 .5],[iou50val iou50val],'r');
%         text( 0, iou50val-.025, num2str( iou50val) ); 
%         xlabel('IOU between sample and GT box');
%         ylabel('empicrical cummulative distribution');title(situation_struct.situation_objects{oi});
%         xlim([0 1.01])
%         ylim([0 1.01])
%     end
%     
%     % remodel the situation with the 
%     
%     remodeled_mu = mean(resampled_big_vector);
%     remodeled_Sigma = cov(resampled_big_vector);
%     row_description_appended = {'r0' 'rc' 'rf' 'c0' 'cc' 'cf' 'log w' 'log h' 'log aspect ratio' 'log area ratio','iou guestimate'}; 
%     
%     want_data_inds = false(1,numel(remodeled_mu)); want_data_inds(1:10) = true; % want distribution for person
%     have_data_inds = false(1,numel(remodeled_mu)); have_data_inds(11) = true; % have only the IOU
%     known_data = nan(1,numel(remodeled_mu)); 
%     known_data(11) = .5;
%     [mu_hat, Sigma_hat] = mvn_marginalize_and_condition(remodeled_mu,remodeled_Sigma, want_data_inds, have_data_inds, known_data );
%     
%    tempx = ious_big;
%    tempx( tempx<exp(-8) ) = 0;
%    figure;  hist(log(tempx),50); legend(situation_struct.situation_objects);
%    ylim([0 22000]);
%    xlabel('log iou from sampled boxes');
%    ylabel('data frequency');
%     title('log iou prior');
%     
    %% get densities for different levels of conditioning
    
    if exist('densities.mat','file')
        load('densities.mat');
    else
    
    density_prior          = nan( length(training_rows), length(situation_struct.situation_objects));
    density_conditioned_0  = nan( length(training_rows), length(situation_struct.situation_objects));
    density_conditioned_1a = nan( length(training_rows), length(situation_struct.situation_objects));
    density_conditioned_1b = nan( length(training_rows), length(situation_struct.situation_objects));
    density_conditioned_2  = nan( length(training_rows), length(situation_struct.situation_objects));
    
    density_prior_uniform = nan( length(training_rows), length(situation_struct.situation_objects));
    
    for imii = 1:length(training_im_inds)
        
        imi = training_im_inds(imii);
        cur_data_rows = find(eq(d.fname_source_index,imi));
        
        im_rows = labl_data_training(imii).im_h;
        im_cols = labl_data_training(imii).im_w;
        
        workspaces_dummy = make_dummy_workspaces( labl_data_training(imii), situation_struct );
        workspace_full = workspaces_dummy{end};
        
        
        for oi = 1:num_objs
            
            cur_obj = situation_struct.situation_objects{oi};
            
            % cond 2
            dummy2 = workspace_full;
            wi = find( strcmp( workspace_full.labels, cur_obj) );
            assert( wi == oi);
            dummy2.boxes_r0rfc0cf(oi,:) = [];
            dummy2.labels(oi) = [];
            normal_dist_model_conditioned_2 = situation_models.normal_condition( normal_dist_model_prior, cur_obj, dummy2 );
            
            % cond 1a
            dummy1a = dummy2;
            dummy1a.boxes_r0rfc0cf(1,:) = [];
            dummy1a.labels(1) = [];
            normal_dist_model_conditioned_1a = situation_models.normal_condition( normal_dist_model_prior, cur_obj, dummy1a );
            
            % cond 1b
            dummy1b = dummy2;
            dummy1b.boxes_r0rfc0cf(2,:) = [];
            dummy1b.labels(2) = [];
            normal_dist_model_conditioned_1b = situation_models.normal_condition( normal_dist_model_prior, cur_obj, dummy1b );
            
            
            for rii = 1:length(cur_data_rows)
                ri = cur_data_rows(rii);
                cur_box_r0rfc0cf = d.box_proposals_r0rfc0cf(ri,:);
                [~,density_prior(ri,oi)]          = situation_models.normal_sample( normal_dist_model_prior, cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
                [~,density_conditioned_0(ri,oi)]  = situation_models.normal_sample( normal_dist_model_prior, cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
                [~,density_conditioned_1a(ri,oi)] = situation_models.normal_sample( normal_dist_model_conditioned_1a, cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
                [~,density_conditioned_1b(ri,oi)] = situation_models.normal_sample( normal_dist_model_conditioned_1b, cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
                [~,density_conditioned_2(ri,oi)]  = situation_models.normal_sample( normal_dist_model_conditioned_2,  cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
                
                [~,density_prior_uniform(ri,oi)] = situation_models.uniform_sample( uniform_dist_model_prior, cur_obj, [],[im_rows im_cols],cur_box_r0rfc0cf); 
            end
            
        end
            
        progress(imii,length(training_im_inds));
        % display(workspace_full.labels);
        
    end
    
    
    
    

    densities = cat(3,density_conditioned_0,density_conditioned_1a,density_conditioned_1b,density_conditioned_2);
    
    end
     
    conditioning_states = {'obj0','obj1a','obj1b','obj2'};
   
    
%% internal support, p(x|cx)



classifier = load('saved_models/dogwalkerdogleash, IOU ridge regression, 0.mat');

p_cx_x  = @(x,oi) normpdf( x, classifier.model_validation_stats{oi}.mu(2),classifier.model_validation_stats{oi}.sigma(2) );
p_cx_nx = @(x,oi) normpdf( x, classifier.model_validation_stats{oi}.mu(1),classifier.model_validation_stats{oi}.sigma(1) );
p_x_cx_func  = @(x,oi) (1 + ( p_cx_nx(x,oi) * (1-p_x) ) ./ ( p_cx_x(x,oi) * (p_x) ) ).^(-1);

b = @(x) [ones(size(x,1),1) x];

% removing crops that were used to train visual classifiers
training_im_inds_classifier = find(ismember( fileparts_mq( d.fnames, 'name'), classifier.fnames_lb_train));
eval_im_inds = setdiff( training_im_inds, training_im_inds_classifier );
eval_rows = ismember( d.fname_source_index, eval_im_inds );

gt_iou_eval = gt_iou(eval_rows,:);
   

cx = b(d.box_proposal_cnn_features(eval_rows,:)) * cat(2,classifier.models{:});

p_x_cx = nan( size(cx,1), num_objs);
for oi = 1:num_objs
    p_x_cx(:,oi) = p_x_cx_func( cx(:,oi), oi );
end

figure('color','white','name','visual classifier');
for oi = 1:numel(situation_struct.situation_objects)
    subplot(1,numel(situation_struct.situation_objects),oi);
    plot( cx(:,oi), gt_iou_eval(:,oi),'.');
    xlabel('cx');
    ylabel('gt iou');
    title(situation_struct.situation_objects{oi});
    text( -.45,.95, ['corr: ' num2str(corr(cx(:,oi), gt_iou_eval(:,oi)),3)] )
    xlim([-.5 1.25])
end


figure('color','white','name','visual classifier');
for oi = 1:numel(situation_struct.situation_objects)
    subplot(1,numel(situation_struct.situation_objects),oi);
    plot( p_x_cx(:,oi), gt_iou_eval(:,oi),'.');
    xlabel('p(x|cx)');
    ylabel('gt iou');
    title(situation_struct.situation_objects{oi});
    text( .05,.95, ['corr: ' num2str(corr(p_x_cx(:,oi), gt_iou_eval(:,oi)),3)] )
    xlim([0 1])
end




    
    
%% visualizing conditioned densities and ratio
  
    

    p_x = .003;
    
    p_bx = .0922;
    psi = log( p_bx ) + log(1-p_x) - log( densities + .0001 ) - log( p_x );
    p_x_bxyby = ( 1 + exp(psi) ).^(-1);
    p_x_bxyby_blob = p_x_bxyby(:);
     
    gt_iou_rep = repmat(gt_iou,1,1,size(p_x_bxyby,3));
    gt_iou_blob = gt_iou_rep(:);
    
    gt_iou_rep_eval = gt_iou_rep( eval_rows, :, : );
   
    figure;
    plot( gt_iou_blob( sortorder( p_x_bxyby_blob) ),'.')
    plot( local_stat( gt_iou_blob( sortorder( p_x_bxyby_blob) ), 10 ) );
    xlabel('index');
    ylabel('local gt iou');
    
%     b_bx_x = densities(:,:,1);
%     psi2 = log( repmat(b_bx_x,[1,1,size(densities,3)]) ) + log(1-p_x) - log( densities + .01 ) - log( p_x );
%     p_x_bxyby2 = (1 + exp(psi2) ).^(-1);
%     p_x_bxyby2_blob = p_x_bxyby2(:);

    
    for oi = 1:numel(situation_struct.situation_objects)
        figure('name',situation_struct.situation_objects{oi});
        for ci = 1:numel(conditioning_states)
        for cj = 1:numel(conditioning_states)
            subplot2( numel(conditioning_states), numel(conditioning_states), ci, cj);
            if ci ~= cj
                subind = 1:100:size(p_x_bxyby,1);
                plot( p_x_bxyby(subind,oi,ci), p_x_bxyby(subind,oi,cj),'.' );
            else
                hist_unit( p_x_bxyby(:,oi,ci), 50 );
            end
            if cj == 1
                ylabel(conditioning_states{ci});
            end
            if ci == 1
                title(conditioning_states{cj});
            end
        end
        end
    end
            

    
    
    tweak = -1 * (log(p_bx) + log(1-p_x) - log(p_x));

    
    
    % per object/conditioning state hists
    figure('color','white')
    set(gcf,'position',[474 193 800 750]);
    conditioning_objects = cell(num_objs, numel(conditioning_states) );
    for oi = 1:num_objs
    for ci = 1:numel(conditioning_states)
        
        subplot2(numel(conditioning_states), num_objs, ci, oi);
       
        hist_unit( p_x_bxyby(:,oi,ci), 20 );
        
        if ci == numel(conditioning_states)
            xlabel({'p(x|b_x,y,b_y)'});
        end
        
         if oi == 1
            ylabel('data ratio');
        end
            
        temp =  situation_struct.situation_objects;
        temp(oi) = [];
        if ci == 1
            conditioning_objects{oi,ci} = 'none';
        elseif ci == 2
            conditioning_objects{oi,ci} = temp{1};
        elseif ci == 3
            conditioning_objects{oi,ci} = temp{2};
        elseif ci == 4
            conditioning_objects{oi,ci} = [temp{1} ', ' temp{2}];
        end
        conditioning_description = {['conditioned on: ' conditioning_objects{oi,ci}]};
        if ci ==1
            conditioning_description = [situation_struct.situation_objects{oi} conditioning_description];
        end
        title(conditioning_description);
        
        ylim([0,1])
       
    end
    end
    
    
    
    
    
    
    
    
    % scatter p_x_bxyby and gt iou
    figure('color','white')
    set(gcf,'position',[474 193 800 750]);
    for oi = 1:num_objs
    for ci = 1:numel(conditioning_states)
        
        subplot2(numel(conditioning_states), num_objs, ci, oi);
       
        subind = 1:100:size(gt_iou,1);
        plot( p_x_bxyby(subind,oi,ci), gt_iou(subind,oi), '.' );
        
        if ci == numel(conditioning_states)
            xlabel({'p(x|b_x,y,b_y)'});
        end
        
         if oi == 1
            ylabel('gt IOU');
        end
            
        conditioning_description = ['conditioned on: ' conditioning_objects{oi,ci}];
        if ci ==1
            conditioning_description = {situation_struct.situation_objects{oi}, conditioning_description};
        end
        title(conditioning_description);
       
    end
    end
    
    
    
    
    average_method = 'bin average p';
    switch average_method
        case 'moving average iou'

            for oi = 1:num_objs
            for ci = 1:numel(conditioning_states)
                [~,sort_order] = sort( p_x_bxyby(:,oi,ci) );
                local_mu = local_stat(gt_iou(sort_order,oi),2000);
                subplot2(numel(conditioning_states),num_objs,ci,oi);
                hold on;
                plot( p_x_bxyby(sort_order,oi,ci), local_mu, 'r');
                h = plot( p_x_bxyby(sort_order(1),oi,ci), local_mu(1), '.r','markersize',20);
                plot( p_x_bxyby(sort_order(end),oi,ci), local_mu(end), '.r','markersize',20);
                hold off;
                if oi==num_objs && ci == 1
                    legend(h,'first and last');
                end
            end
            end
            
        case 'moving average p'

            for oi = 1:num_objs
            for ci = 1:numel(conditioning_states)
                [~,sort_order] = sort( p_x_bxyby(:,oi,ci) );
                local_mu = local_stat(double(gt_iou(sort_order,oi)>.5),100);
                subplot2(numel(conditioning_states),num_objs,ci,oi);
                hold on;
                plot( p_x_bxyby(sort_order,oi,ci), local_mu, 'r');
                h = plot( p_x_bxyby(sort_order(1),oi,ci), local_mu(1), '.r','markersize',20);
                plot( p_x_bxyby(sort_order(end),oi,ci), local_mu(end), '.r','markersize',20);
                hold off;
                if oi==num_objs && ci == 1
                    legend(h,'first and last');
                end
            end
            end
            
        case 'bin average p'
    
            n = 50;
            for oi = 1:num_objs
            for ci = 1:numel(conditioning_states)
                [bin_assignments,bin_edges,bin_centers] = bin_prctile(p_x_bxyby(:,oi,ci),n);
                bin_mus = nan(1,n);
                for bi = 1:n
                   bin_mus(bi) = mean(  gt_iou( bin_assignments == bi, oi ) > .5 );
                end
                entries_remove = isnan(bin_mus);
                bin_centers(entries_remove) = [];
                bin_mus(entries_remove) = [];
                
                subplot2(numel(conditioning_states),num_objs,ci,oi);
                hold on;
                    plot( bin_centers, bin_mus, 'r','linewidth',2);
                    h = plot( bin_centers(1), bin_mus(1), '.r','markersize',20);
                    plot( bin_centers(end), bin_mus(end), '.r','markersize',20);
                hold off;
                if oi==num_objs && ci == 1
                    legend(h,'first and last bin');
                end
                xlim([0,1])
                ylim([0,1])
            end
            end
            
    end

    
    
    % dist of iou == 0 for each object
    % consider looking at distance from box center to gt box center. see how that relates
    % ideally, we'd have some uniformly sampled stuff to train from.
    figure;
    for oi = 1:num_objs
        subplot(1,num_objs,oi);
        hist( reshape( p_x_bxyby( gt_iou(:,oi) == 0, oi, 2:end), 1, [] ), 20 );
        title( situation_struct.situation_objects{oi} );
    end
        
%     
%         
%     
%     figure;
%     subplot(1,3,1); 
%         hist( p_x_bxyby(:),20);
%         xlabel('p(x|bx,y,by)');
%         ylabel('data frequency');
%     subplot(1,3,2); 
%         sub_ind = 1:100:numel(p_x_bxyby_blob);
%         plot( p_x_bxyby_blob(sub_ind), gt_iou_blob(sub_ind), '.' );
%         hold on;
%         plot( bin_centers, bin_means, '-r', 'linewidth',2 );
%         xlabel('p(x|bx,y,by)');
%         ylabel('mean gt IOU');
%         xlim([0,1]);
%     subplot(1,3,3);
%         sub_ind = 1:100:numel(p_x_bxyby_blob);
%         plot( p_x_bxyby_blob(sub_ind), gt_iou_blob(sub_ind), '.' );
%         hold on;
%         plot( bin_centers, p_gt_over_50, '-r', 'linewidth',2 );
%         xlabel('p(x|bx,y,by)');
%         ylabel('p( gt IOU > .5)');
        
% estimating data percentile from density, with cutoffs








   
    
%% combining
%  
% gt_iou_rep_eval = repmat(gt_iou_eval,1,1,size(p_x_bxyby,3));
% gt_iou_blob_eval = gt_iou_rep_eval(:);
% 
% p_x_bxyby_blob = reshape( p_x_bxyby(eval_rows,:,:), 1, [] );
% gt_iou_blob    = reshape( repmat(gt_iou(eval_rows,:),1,1,numel(conditioning_states) ), 1, [] );
% p_x_cx_blob    = reshape( repmat( p_x_cx,1,1,numel(conditioning_states) ), 1, []);
% 
% % scatter
% %sub_ind = 1:100:numel(gt_iou_blob);
% figure;
% 
% subplot(1,3,1);
%     plot(log(p_x_cx_blob),gt_iou_blob,'.');
%     xlabel('log p(x|cx)')
%     ylabel('gt iou');
%     
% subplot(1,3,2);
%     plot(log(p_x_bxyby_blob),gt_iou_blob,'.');
%     xlabel('log p(x|bx,y,by)')
%     ylabel('gt iou');
%     
% subplot(1,3,3);
%     plot(log(p_x_bxyby_blob) + log(p_x_cx_blob), gt_iou_blob,'.');
%     xlabel('log p(x|cx) + log p(x|bx,y,by)')
%     ylabel('gt iou');
    
    
  
%% combine internal and external support

log_p_x_cx_bxyby = log( p_x_bxyby(eval_rows,:,:) ) + log( repmat(p_x_cx,1,1,numel(conditioning_states)) ) - log( p_x );

p_x_cx_bxyby = p_x_bxyby(eval_rows,:,:) .* repmat(p_x_cx,1,1,numel(conditioning_states));

for oi = 1:num_objs
    display(situation_struct.situation_objects{oi});

    sub_ind = 1:5:size(p_x_cx_bxyby,1);
    
    fprintf('\n');
    fprintf( 'corr gt/cond 0:  %f\n', corr(gt_iou_eval(:,oi), p_x_cx_bxyby( :, oi, 1 ) ) );
    fprintf( 'corr gt/cond 1a: %f\n', corr(gt_iou_eval(:,oi), p_x_cx_bxyby( :, oi, 2 ) ) );
    fprintf( 'corr gt/cond 1b: %f\n', corr(gt_iou_eval(:,oi), p_x_cx_bxyby( :, oi, 3 ) ) );
    fprintf( 'corr gt/cond 2:  %f\n', corr(gt_iou_eval(:,oi), p_x_cx_bxyby( :, oi, 4 ) ) );
    
    fprintf('\n');
    auroc0  = ROC( log_p_x_cx_bxyby( sub_ind, oi, 1 ), gt_iou_eval(sub_ind,oi)>.5, 1 );
    auroc1a = ROC( log_p_x_cx_bxyby( sub_ind, oi, 2 ), gt_iou_eval(sub_ind,oi)>.5, 1 );
    auroc1b = ROC( log_p_x_cx_bxyby( sub_ind, oi, 3 ), gt_iou_eval(sub_ind,oi)>.5, 1 );
    auroc2  = ROC( log_p_x_cx_bxyby( sub_ind, oi, 4 ), gt_iou_eval(sub_ind,oi)>.5, 1 );
    fprintf( 'auroc gt/cond 0:  %f\n', auroc0 );
    fprintf( 'auroc gt/cond 1a: %f\n', auroc1a );
    fprintf( 'auroc gt/cond 1b: %f\n', auroc1b );
    fprintf( 'auroc gt/cond 2:  %f\n', auroc2 );
    
%     temp_px = squeeze(log_p_x_cx_bxyby(:,oi,:));
%     temp_gt = squeeze(repmat(gt_iou_eval(:,oi),1,1,numel(conditioning_states)));
%     auroc_comb = ROC( temp_px(:), temp_gt(:) > .5, 1 );
%     fprintf( 'auroc gt/combined conditions:  %f\n', auroc_comb ); 
    
    fprintf('\n\n');
    
end

% very minor benefit on the face of it

%%
% scatter p(x|cx,bx,yby) vs iou

figure('color','white','position',[250 400 842 517])
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    
    subplot2(num_objs,numel(conditioning_states),oi,ci);
    
    plot( p_x_cx_bxyby(:,oi,ci), gt_iou_eval(:,oi), '.' );
    
    %display_val = ROC(temp(subind,oi,ci), gt_iou(subind,oi)>=.5);
    %text( .05, .95, ['auroc:' num2str(display_val,3)]);
    display_val = corr(p_x_cx_bxyby(:,oi,ci), gt_iou_eval(:,oi),'rows','complete');
    text( .05, .95, ['corr: ' num2str(display_val,3)]);
    
    if oi == num_objs, xlabel('p(x|c_x,b_x,y,b_y,c_y)'); end
    if ci == 1, ylabel({situation_struct.situation_objects{oi},'gt iou'}); end
    title(['conditioned on: \{ ' conditioning_objects{oi,ci} ' \}']);
    
end
end
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    subplot2(num_objs,4,oi,ci);
    xlim([0,1]);
    ylim([0,1]);
end
end


% average iou, sorted by p(x|cx,bx,yby) index

figure('color','white','position',[250 400 842 517])
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    
    subplot2(num_objs,numel(conditioning_states),oi,ci);
    
    index_ordering = sortorder(p_x_cx_bxyby(:,oi,ci));
    local_mu = local_stat( gt_iou_eval( index_ordering, oi )', 1000 );
    plot( local_mu );
    
    
    if oi == num_objs, xlabel('p(x|c_x,b_x,y,b_y,c_y) index'); end
    if ci == 1, ylabel({situation_struct.situation_objects{oi},'local mean gt iou'}); end
    title(['conditioned on: \{ ' conditioning_objects{oi,ci} ' \}']);
    
end
end
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    subplot2(num_objs,4,oi,ci);
    ylim([0,1]);
    xlim([0,size(p_x_cx_bxyby,1)])
    xticks([]);
end
end




% beta cdf wrapped p(x|cx,bx,yby) vs iou
phat = betafit( p_x_cx_bxyby(:) );
wrapper0 = @(x) betacdf( x, phat(1), phat(2) );
temp = wrapper0( p_x_cx_bxyby );
min_val = min(temp(:));
max_val = max(temp(:));
wrapper = @(x) (betacdf( x, phat(1), phat(2) ) - min_val) ./ (max_val-min_val);
temp = wrapper( p_x_cx_bxyby );

figure('color','white','position',[250 400 842 517])
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    
    
    subplot2(num_objs,numel(conditioning_states),oi,ci);
    
    subind = 1:50:size(log_p_x_cx_bxyby,1);
    plot( temp(subind,oi,ci), gt_iou_eval(subind,oi), '.' );
    
    subind = 1:10:size(log_p_x_cx_bxyby,1);
    %display_val = ROC(temp(subind,oi,ci), gt_iou(subind,oi)>=.5);
    %text( .05, .95, ['auroc:' num2str(display_val,3)]);
    display_val = corr(temp(subind,oi,ci), gt_iou_eval(subind,oi),'rows','complete');
    text( .05, .95, ['corr: ' num2str(display_val,3)]);
    
    if oi == num_objs, xlabel('external support'); end
    if ci == 1, ylabel({situation_struct.situation_objects{oi},'gt iou'}); end
    title(['conditioned on: \{ ' conditioning_objects{oi,ci} ' \}']);
    
end
end
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    subplot2(num_objs,4,oi,ci);
    xlim([0,1]);
    ylim([0,1]);
end
end

%% beta wrap internal and external, them mix


% beta cdf wrapped p(x|cx,bx,yby) vs iou
cx_rep = repmat( cx, [1,1,size(p_x_bxyby,3)] );
p_x_cx_rep = repmat( p_x_cx, [1,1,size(p_x_bxyby,3)] );
phat_internal = betafit( p_x_cx(:) );
phat_external = betafit( p_x_bxyby(:) );

phat_total = betafit( p_x_cx_bxyby(:) );



% linear combo, 1 param
total_support_func = @( int, ext, t ) t(1) * int + (1-t(1)) * ext;
t0 = [ .5 ];
tf = zeros( num_objs, numel(t0) );
internal_support = cx_rep;
external_support = mat2gray( betacdf( p_x_bxyby(eval_rows,:,:), phat_external(1), phat_external(2) ) );
total_support_1p = nan(size(cx_rep));
subscore = nan(1,num_objs);
for oi = 1:num_objs
    subind = 1:10:size(internal_support,1);
    [tf(oi,:), subscore(oi)] = ...
        fminsearch( @(t) ...
            1-ROC( ...
                total_support_func( internal_support(subind,oi,2:end), external_support(subind,oi,2:end), t ), ...
                gt_iou_rep_eval(subind,oi,2:end) > .5...
            ) + ...
            .5 * rmse( ...
                total_support_func( internal_support(:,oi,2:end), external_support(:,oi,2:end), t ), ...
                gt_iou_rep_eval(:,oi,2:end)...
            ), ...
        t0 );
    fprintf('.');
end
for oi = 1:3
    total_support_1p(:,oi,:) = total_support_func( internal_support(:,oi,:), external_support(:,oi,:), tf(oi) );
end
% 
% % linear combo, 4 param
% total_support_func = @( int, ext, t ) t(1) + t(2) * int + t(3) * ext + t(4) * int.*ext;
% eps = .01;
% L1 = @(x) sum( abs(x) );
% L0 = @(x) sum( abs(x) > eps );
% t0 = [ 0 .3 .3 .3 ];
% tf = zeros( num_objs, numel(t0) );
% internal_support = cx_rep;
% external_support = mat2gray( betacdf( p_x_bxyby(eval_rows,:,:), phat_external(1), phat_external(2) ) );
% total_support_4p = nan(size(cx_rep));
% for oi = 1:num_objs
%     subind = 1:10:size(internal_support,1);
%     tf(oi,:) = ...
%         fminsearch( @(t) ...
%             1-ROC( ...
%                 total_support_func( internal_support(subind,oi,2:end), external_support(subind,oi,2:end), t ), ...
%                 ( gt_iou_rep_eval(subind,oi,2:end) > .5 )...
%             ) + ...
%             .5 * rmse( ...
%                 total_support_func( internal_support(:,oi,2:end), external_support(:,oi,2:end), t ), ...
%                 target_wrapper( gt_iou_rep_eval(:,oi,2:end) )...
%             ) + .01 * L1(t), ...
%         t0 );
%     fprintf('.');
% end
% for oi = 1:3
%     total_support_4p(:,oi,:) = total_support_func( internal_support(:,oi,:), external_support(:,oi,:), tf(oi,:) );
% end





% linear combo, 1 shared, 1 param per object
% does worse to do it this way than to do it explicitly per object, but should be compared against a
% function of the auroc, not the auroc-free method. when compared against just fitting a linear
% function to the coeffs that come out of the above, this does in fact do better


n = 10;
[A,B]= meshgrid(linspace(.2,.8,n),linspace(.2,.8,n));
C = [A(:) B(:)];
C_sum = sum(C,2);
%rows_remove = C_sum > 1.4 | C_sum < .6 | min(C,[],2) < .05;

%C(rows_remove,:) = [];
%C_sum(rows_remove) = [];

f_val = nan(size(C,1),1);

int_temp = reshape(shiftdim(internal_support(:,:,2:end),1),3,[])';
ext_temp = reshape(shiftdim(external_support(:,:,2:end),1),3,[])';
iou_temp = reshape(shiftdim(gt_iou_rep_eval(:,:,2:end),1),3,[])';
temp_aurocs = [classifier.AUROCs];
temp_aurocs = 2* (temp_aurocs-.5);

% % pad with a garbage classifier
% int_temp = [ int_temp rand(size(int_temp,1),1) ];
% ext_temp = [ ext_temp ext_temp(:,3) ];
% iou_temp = [ iou_temp iou_temp(:,3) ];
% temp_aurocs = [temp_aurocs 0];

for ci = 1:size(C,1)
    t = C(ci,:);
    f_val(ci) = scorefunc( int_temp, ext_temp, iou_temp, temp_aurocs, t );
    progress(ci,size(C,1)); 
end

grid_val = max( f_val ) * ones(size(A));
for ci = 1:size(C,1)
    grid_val( find(eq(A(1,:),C(ci,1))), find(eq(B(:,1),C(ci,2))) ) = f_val(ci);
end
figure
imshow(grid_val,[])

c_val_final = C(argmin(f_val),:);
[~,c_func] = scorefunc( int_temp, ext_temp, iou_temp, temp_aurocs, c_val_final );
final_mixing_coef = c_func( c_val_final, temp_aurocs)
    
        

%int_temp = [int_temp rand(size(int_temp,1),1)];
%ext_temp = [ext_temp ext_temp(:,3)];
%iou_temp = [iou_temp iou_temp(:,3)];
%temp_aurocs = [temp_aurocs .5];

t0 = C(argmin(f_val),:);
options = [];
options.Display = 'iter';
options.MaxIter = 100;
[tf_comb,final_fval] = fminsearch( @(t) scorefunc( int_temp, ext_temp, iou_temp, temp_aurocs, t ), t0, options );
%[tf_comb,final_fval] = fminsearch( @(t) scorefunc( int_temp(:,[3]), ext_temp(:,[3]), iou_temp(:,[3]), temp_aurocs(:,[3]), t ), t0, options );

num_iter = 50;
delta0 = 1;
decay = .9;
%cur_t = [0.7568    2.3136    0.8978]; % -0.3794
%cur_t = [ 0.0867    1.7002    0.4966]; % -0.3810
cur_t =[-0.6114    2.0952    0.2573]; %  -0.3801 % using normal search

t_best = cur_t;
f_val_best = inf;
for iter = 1:num_iter
    %sign = (-1).^floor((iter-1)/3);
    %mag = delta0 * decay^(iter - 1);
    %cur_step = sign * mag;
    %cur_delta = zeros(size(cur_t));
    %cur_delta( mod(iter,numel(cur_t))+1 ) = cur_step;
    %cur_t = t_best + cur_delta;
    
    cur_t = t_best + randn(1,3)/12;
    
    
    f_val = scorefunc( int_temp, ext_temp, iou_temp, temp_aurocs, cur_t );
    if f_val < f_val_best
        t_best = cur_t;
        f_val_best = f_val;
    end
    display([num2str(iter) ':  ' num2str(cur_t,'%1.4f  ') ': ' num2str(f_val)]);
end
    
    

[~,c_func] = scorefunc( int_temp, ext_temp, iou_temp, temp_aurocs, t_best );

display( c_func(t_best,temp_aurocs) )





% % when a "junk classifier" is included
% c = -0.9337  +  1.9045 * auroc
% -0.9337  +  1.9045 * auroc = a + b*2*(auroc-.5) = a + 2b*auroc - b = a-b + 2b*auroc
% => b = 1.9045/2 = .9523
% => a-b = -0.9337 => a = -0.9337 + .9523 = 0.0186
% c = 0.0186 + .9523 * 2(auroc-.5)
% => absolute minimum internal support = 0.0186
% => absolute maximum internal support = 0.9709
% resulting internal support weights: 0.8835    0.8991    0.5621

% % when no "junk classifier" is included
% c = 0.1015 + 0.8152 * auroc
% b = 0.8152/2 = 0.4076
% a = 0.1015 + b = 0.1015 + 0.4076 = 0.5091
% c = 0.5091 + 0.4076 * 2(auroc-.5)
% resulting internal support weights:  0.8793    0.8860    0.7418




% compare pxcxbxyby to f_beta(px) to linear combo


figure('color','white','name','corr and auroc for pxcxbx','position',[550   350   760   650])
ymax = -inf;

corr_p  = nan(1,3);
auroc_p = nan(1,3);
rmse_p  = nan(1,3);

corr_f  = nan(1,3);
auroc_f = nan(1,3);
rmse_f  = nan(1,3);

corr_h  = nan(1,3);
auroc_h = nan(1,3);
rmse_h  = nan(1,3);

corr_h1  = nan(1,3);
auroc_h1 = nan(1,3);
rmse_h1  = nan(1,3);


for oi = 1:3
    
    % p vs iou
    subplot2(4,3,1,oi);
    n = hist(flat(p_x_cx_bxyby(:,oi,:)),20);
    hist(flat(p_x_cx_bxyby(:,oi,:)),20);
    title(situation_struct.situation_objects{oi});
    xlabel('p(x|cx,bx,y,by)');
    ylabel('data frequency');
    xlim([0 1]);
    ymax = max( ymax, max(n) );
    
    corr_p(oi) = corr( flat(p_x_cx_bxyby(:,oi,:)), flat(gt_iou_rep_eval(:,oi,:)) );
    auroc_p(oi) = ROC( flat(p_x_cx_bxyby(1:10:end,oi,:)), flat(gt_iou_rep_eval(1:10:end,oi,:)) > .5 );
    rmse_p(oi) = rmse(  flat(p_x_cx_bxyby(1:10:end,oi,:)), flat(gt_iou_rep_eval(1:10:end,oi,:)) );
    
    % f_{beta}(p) vs iou
    subplot2(4,3,2,oi);
    %phat_total = betafit( flat(p_x_cx_bxyby(:,oi,:)) );
    beta_cdf_p_x_cx_bxyby = betacdf( p_x_cx_bxyby(:,oi,:), phat_total(1), phat_total(2) );
    hist(beta_cdf_p_x_cx_bxyby(:),20);
    n = hist(beta_cdf_p_x_cx_bxyby(:),20);
    xlabel('f_{\beta}(x|cx,bx,y,by)');
    ylabel('data frequency');
    xlim([0 1]);
    ymax = max( ymax, max(n) );
    
    corr_f(oi) = corr( flat(beta_cdf_p_x_cx_bxyby), flat(gt_iou_rep_eval(:,oi,:)) );
    auroc_f(oi) = ROC( flat(beta_cdf_p_x_cx_bxyby(1:10:end,:,:)), flat(gt_iou_rep_eval(1:10:end,oi,:)) > .5 );
    rmse_f(oi) = rmse( flat(beta_cdf_p_x_cx_bxyby), flat(gt_iou_rep_eval(:,oi,:)) );
    
    % h( f_{beta}(p), cx ) vs iou
    subplot2(4,3,3,oi);
    hist(flat(total_support_1p(:,oi,:)),20);
    n = hist(flat(total_support_1p(:,oi,:)),20);
    xlabel('h1(cx, f_{\beta}(x|bx,y,by))');
    ylabel('data frequency');
    xlim([-.25 1.1]);
    ymax = max( ymax, max(n) );
    
    corr_h1(oi) = corr( flat(total_support_1p(:,oi,:)), flat(gt_iou_rep_eval(:,oi,:)) );
    auroc_h1(oi) = ROC( flat(total_support_1p(1:10:end,oi,:)), flat(gt_iou_rep_eval(1:10:end,oi,:)) > .5 );
    rmse_h1(oi) = rmse( flat(total_support_1p(:,oi,:)), flat(gt_iou_rep_eval(:,oi,:)) );
    
    
    % h( f_{beta}(p), cx ) vs iou
    subplot2(4,3,4,oi);
    hist(flat(total_support_4p(:,oi,:)),20);
    n = hist(flat(total_support_4p(:,oi,:)),20);
    xlabel('h4(cx, f_{\beta}(x|bx,y,by))');
    ylabel('data frequency');
    xlim([-.25 1.1]);
    ymax = max( ymax, max(n) );
    
    corr_h(oi) = corr( flat(total_support_4p(:,oi,:)), flat(gt_iou_rep_eval(:,oi,:)) );
    auroc_h(oi) = ROC( flat(total_support_4p(1:10:end,oi,:)), flat(gt_iou_rep_eval(1:10:end,oi,:)) > .5 );
    rmse_h(oi) = rmse( flat(total_support_4p(:,oi,:)), flat(gt_iou_rep_eval(:,oi,:)) );
    
end
ymax = ymax*1.1;
for oi = 1:3
    
    subplot2(4,3,1,oi);
    
    ylim([0 ymax]);
    text(.6,.95*ymax, ['corr:  ' num2str(corr_p(oi),3)]);
    text(.6,.85*ymax, ['auroc: ' num2str(auroc_p(oi),3)]);
    text(.6,.75*ymax, ['rmse:  ' num2str(rmse_p(oi),3)]);
    
    subplot2(4,3,2,oi);
    
    ylim([0 ymax/2]);
    text(.6,.95*ymax/2, ['corr:  ' num2str(corr_f(oi),3)]);
    text(.6,.85*ymax/2, ['auroc: ' num2str(auroc_f(oi),3)]);
    text(.6,.75*ymax/2, ['rmse:  ' num2str(rmse_f(oi),3)]);
    
    subplot2(4,3,3,oi);
    xlim([-.25 1.1]);
    ylim([0 ymax/2]);
    text(.55,.95*ymax/2, ['corr:  ' num2str(corr_h1(oi),3)]);
    text(.55,.85*ymax/2, ['auroc: ' num2str(auroc_h1(oi),3)]);
    text(.55,.75*ymax/2, ['rmse:  ' num2str(rmse_h1(oi),3)]);
    
    subplot2(4,3,4,oi);
    xlim([-.25 1.1]);
    ylim([0 ymax/2]);
    text(.55,.95*ymax/2, ['corr:  ' num2str(corr_h(oi),3)]);
    text(.55,.85*ymax/2, ['auroc: ' num2str(auroc_h(oi),3)]);
    text(.55,.75*ymax/2, ['rmse:  ' num2str(rmse_h(oi),3)]);
    
end
    




%%

                                    



figure('color','white','position',[250 400 842 517])
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    
    
    subplot2(num_objs,numel(conditioning_states),oi,ci);
    
    subind = 1:100:size(log_p_x_cx_bxyby,1);
    plot( temp(subind,oi,ci), gt_iou(subind,oi), '.' );
    
    subind = 1:10:size(log_p_x_cx_bxyby,1);
    %display_val = ROC(temp(subind,oi,ci), gt_iou(subind,oi)>=.5);
    %text( .05, .95, ['auroc:' num2str(display_val,3)]);
    display_val = corr(temp(subind,oi,ci), gt_iou(subind,oi),'rows','complete');
    text( .05, .95, ['corr: ' num2str(display_val,3)]);
    
    if oi == num_objs, xlabel('external support'); end
    if ci == 1, ylabel({situation_struct.situation_objects{oi},'gt iou'}); end
    title(['conditioned on: \{ ' conditioning_objects{oi,ci} ' \}']);
    
end
end
for oi = 1:num_objs
for ci = 1:numel(conditioning_states)
    subplot2(num_objs,4,oi,ci);
    xlim([0,1]);
    ylim([0,1]);
end
end


%%
% based on ROC, it really is just an issue of scaling, but that would be per class, which is a lot
% of work, we'd like to be able to just wrap it all up together, which means finding a way to
% combine log_x_cx and log_x_cx_bx_yby. 

% if we're not going to use it for multiplication, we'd like to force it into reasonable bounds so
% we can decide on a mixing factor for combining with internal support


    
% local average
    n = 100;
    mu_over  = nan(1,n);
    mu_under = nan(1,n);
    mu_local = nan(1,n);
    ts = linspace(min(log(p_x_bxyby_blob)),max(log(p_x_bxyby_blob)),n);
    for ti = 1:n
        inds_in_bounds = log(p_x_bxyby_blob) > ts(max(1,ti-1)) & log(p_x_bxyby_blob) < ts(min(n,ti+1));
        mu_local(ti) = mean( gt_iou_blob( inds_in_bounds ) > .5 );
        progress(ti,n);
    end
    
subind = 1:100:numel(p_x_bxyby_blob);
    
figure('color','white')
    subplot(1,2,1);
    plot(log(p_x_bxyby_blob(subind)), gt_iou_blob(subind), '.')
    xlabel('log p_x_ybycy')
    ylabel('local mean gt iou');
    hold on;
    
    %plot(ts,mu_local,'r');
    
    [b,p] = logregfit( log(p_x_bxyby_blob), gt_iou_blob);
    plot(log(p_x_bxyby_blob),p,'.r');
    legend('scatter','logistic estimate using p(x|bx,y,by)','location','northwest');
    xlabel('log p(x|bx,y,by)');
    ylabel('gt iou');
    
    
    subplot(1,2,2);
    plot(p(subind),gt_iou_blob(subind),'.');
    hold on;
    [~,temp] = sort(p);
    mu_local_2 = local_stat( gt_iou_blob(temp(subind)), 500 );
    plot(p(temp(subind)),mu_local_2,'.r');
    xlabel({'external support','logistic of log p(x|bx,y,by)'});
    ylabel('gt iou');
    legend('scatter','local average gt iou');
    
    
    
    
    
%% lets use these as external support

temp = cellfun( @(x) x(:), p_x_bxyby, 'UniformOutput',false);
temp = [temp{:}];
temp = [temp; p_x * ones(size(gt_iou))];

gt_iou_rep = repmat( gt_iou, size(temp,1)/size(gt_iou,1), 1 );

[b,p] = logregfit( log(temp(:)), gt_iou_rep(:)>.5);

ext_sup_func = @(x) glmval( b, log(x), 'logit');
ext_sup_func_bin = @(x) double(ext_sup_func(x) > .21);



int_sup_method = 'cx';
%int_sup_method = 'px';
%ext_sup_method = 'bin';
ext_sup_method = 'cont';

name_str = [];

switch ext_sup_method
    case 'cont'
        ext_sup = cellfun( ext_sup_func, mat2cell(temp,size(temp,1), ones(1,size(temp,2)) ), 'uniformoutput',false );
        ext_sup = [ext_sup{:}];
        name_str = [name_str ' ext sup: cont '];  
    case 'bin'
        ext_sup = cellfun( ext_sup_func_bin, mat2cell(temp,size(temp,1), ones(1,size(temp,2)) ), 'uniformoutput',false );
        ext_sup = [ext_sup{:}];
        name_str = [name_str ' ext sup: bin '];  
end


switch int_sup_method
    case 'px'
        int_sup = repmat( p_x_cx, size(ext_sup,1)/size(cx,1), 1 );
        name_str = [name_str ' int sup: px '];
    case 'cx'
        int_sup = repmat( cx, size(ext_sup,1)/size(cx,1), 1 );
        name_str = [name_str ' int sup: cx '];
end


figure('name',name_str,'color','white','position',[ 358,78,1200,725]);

for oi = 1:num_objs
    
    subind = 1:100:size(ext_sup,1);
    
    subplot2(num_objs,5,oi,1);
    curval = int_sup;
    plot(curval(subind,oi),gt_iou_rep(subind,oi),'.')
    auroc =  ROC( curval(subind,oi), gt_iou_rep(subind,oi)>.5 );
    corr_coeff = corr( curval(subind,oi), gt_iou_rep(subind,oi), 'rows', 'complete' );
    title(sprintf('auc: %.2f, corr: %.2f',auroc, corr_coeff ) );
    if oi == num_objs, xlabel('int sup'); end
    xlim([-.25 1.25])
    ylabel({situation_struct.situation_objects{oi},'gt iou'});
    
    
    subplot2(num_objs,5,oi,2);
    curval = ext_sup;
    plot(curval(subind,oi),gt_iou_rep(subind,oi),'.')
    auroc =  ROC( curval(subind,oi), gt_iou_rep(subind,oi)>.5 );
    corr_coeff = corr( curval(subind,oi), gt_iou_rep(subind,oi), 'rows', 'complete' );
    title(sprintf('auc: %.2f, corr: %.2f',auroc, corr_coeff ) );
    if oi == num_objs, xlabel('ext sup'); end
    xlim([-.25 1.25])
    
    subplot2(num_objs,5,oi,3);
    curval = int_sup .* ext_sup;
    plot(curval(subind,oi),gt_iou_rep(subind,oi),'.')
    auroc =  ROC( curval(subind,oi), gt_iou_rep(subind,oi)>.5 );
    corr_coeff = corr( curval(subind,oi), gt_iou_rep(subind,oi), 'rows', 'complete' );
    title(sprintf('auc: %.2f, corr: %.2f',auroc, corr_coeff ) );
    if oi == num_objs, xlabel('int * ext sup'); end
    xlim([-.25 1.25])
 
    subplot2(num_objs,5,oi,4);
    mx = .5;
    curval = (mx)*int_sup + (1-mx)*ext_sup;
    plot(curval(subind,oi),gt_iou_rep(subind,oi),'.')
    auroc =  ROC( curval(subind,oi), gt_iou_rep(subind,oi)>.5 );
    corr_coeff = corr( curval(subind,oi), gt_iou_rep(subind,oi), 'rows', 'complete' );
    title(sprintf('auc: %.2f, corr: %.2f',auroc, corr_coeff ) );
    if oi == num_objs, xlabel(sprintf('%.2f int + %.2f ext',mx,1-mx)); end
    xlim([-.25 1.25])
    
    
    t0 = [.5 .5];
    total_sup_func = @(t) t(1)*int_sup(:,oi) + t(2)*ext_sup(:,oi);
    tf = fminsearch( @(t) rmse( total_sup_func(t), gt_iou_rep(:,oi) ), t0 );
    
    subplot2(num_objs,5,oi,5);
    curval = repmat(total_sup_func(tf),[1,num_objs]);
    plot(curval(subind,oi),gt_iou_rep(subind,oi),'.')
    auroc =  ROC( curval(subind,oi), gt_iou_rep(subind,oi)>.5 );
    corr_coeff = corr( curval(subind,oi), gt_iou_rep(subind,oi), 'rows', 'complete' );
    title(sprintf('auc: %.2f, corr: %.2f',auroc, corr_coeff ) );
    xlabel({sprintf('rmse fit',mx,1-mx),sprintf('%.2f int + %.2f ext',tf)});
    xlim([-.25 1.25])
    
    display(tf);
    
end
 




















    
    
    
    
  
    
%%
    
    % wrapping function
    option = 'expcdf';
    switch option
        case 'logistic'
            ext_sup_f = @(x,b) b(1) + b(2) * logistic(log(x) - b(4),b(3));
            b_in = [0 1 .1 0];
        case 'expcdf'
            ext_sup_f = @(x,b) b(1) + b(2) * expcdf(x-b(3),b(4));
            b_in = [0 1 0 expfit(glob)];
        case 'atan'
            ext_sup_f = @(x,b) b(2) * atan(b(1)*x);
            b_in = [1, 1];
    end
    
    % target functions
    option = 'handbuilt';
    switch option
        
        case 'handbuilt' % interpolated, hand-built function
            hb_x = prctile( glob(:), [0 50 90 100] ); 
            hb_y = [0 0 1 1];
            interp_func_x = glob();
            interp_func_y = interp1( hb_x, hb_y, interp_func_x, 'linear' );
            y_target = interp_func_y;
            
        case 'empcdf' % empirical cdf
            emp_cdf = cdf_emp(glob);
            y_target = emp_cdf;
            
    end
    
    option = 'optimize';
    switch option
        case 'optimize' % perform minimization
            b_out = fminsearch( @(b) sum((ext_sup_f(glob,b) - reshape(y_target,size(glob))).^2), b_in );
        case 'set' % force b_out to .1
            b_out = [0 1 .1 0];
    end
    
    
    external_support = ext_sup_f(glob,b_out) ./ max( ext_sup_f(glob,b_out) );
    figure; 
    subplot(1,2,1); plot( cdf_emp(glob), external_support,  '.' ); xlabel('empirical cdf'); ylabel('external support'); axis([0 1 -.05 1.05]);
    subplot(1,2,2); plot( external_support,reshape(y_target,size(glob)), '.' ); xlabel('exernal support'); ylabel('target function'); axis([0 1 -.05 1.05]);
    
    figure('color',[1 1 1]);
    subplot(1,3,1); hist( glob, 50); xlabel('raw densities'); ylabel('frequency'); 
    subplot(1,3,2); hist( log(glob), 50); xlabel('log densities'); ylabel('frequency'); xlim([ min(log(glob)) max(log(glob))]);
    subplot(1,3,3); hist( external_support, 50); xlabel({'external support',func2str(ext_sup_f),['with b = (' sprintf('%1.1f, %1.1f, %1.1f',b_out) ')']}); xlim([0 1]);
    
    
    %% pull in trained iou estimates
    
    models_iou = classifiers.IOU_ridge_regression_train(situation_struct,training_fnames,'saved_models/');
    predicted_iou = nan( size(d.box_proposal_cnn_features,1), length(models_iou.classes) );
    for oi = 1:length(models_iou.models)
        predicted_iou(:,oi) = padarray( d.box_proposal_cnn_features, [0 1], 1, 'pre') * models_iou.models{oi};
        progress(oi,length(models_iou.models));
    end
    
    %% look at p(x|cx)
    
    area_under_ratio = nan(1,3);
    AUROC = nan(1,3);
    geomean = nan(1,3);
    average = nan(1,3);
    sum_abs_log_ratio = nan(1,3);
    for oi = 1:3
        
        cur_obj_str = models_iou.classes{oi};
        
        cx_x  = predicted_iou( d.IOUs_with_each_gt_obj(:,oi) >= .5, oi );
        cx_nx = predicted_iou( d.IOUs_with_each_gt_obj(:,oi) < .5,  oi );
      
        % emp distributions
        %min_val = .00001;
        min_val = 0;
        bin_centers = linspace(-.25,1.25,50);
        p_cx_x = hist(cx_x,bin_centers);
        
        p_cx_x = p_cx_x/sum(p_cx_x);
        p_cx_x = p_cx_x + min_val;
        p_cx_x = p_cx_x/sum(p_cx_x);
        p_cx_nx = hist(cx_nx,bin_centers);
        p_cx_nx = p_cx_nx/sum(p_cx_nx);
        p_cx_nx = p_cx_nx + min_val;
        p_cx_nx = p_cx_nx/sum(p_cx_nx);
        
        
        mu_hit     = mean( cx_x );
        sigma_hit  = std(  cx_x );
        mu_miss    = mean( cx_nx );
        sigma_miss = std(  cx_nx );
        
        
        x = linspace(-.5,1.5,1000);
        y_hit = normpdf(x,mu_hit,sigma_hit);
        y_miss = normpdf(x,mu_miss,sigma_miss);
        y_ratio = y_miss./max(y_hit,0);
        y_diff = y_hit-y_miss;
        y_log_ratio = log(y_miss)-log(y_hit);

        threshold = x(find( y_diff > 0, 1, 'first'));
        max_x = max( [(mu_hit + 3*sigma_hit), (mu_miss + 3*sigma_miss)]);
        in_range = x > threshold & x < max_x;
        
        [predicted_iou_sorted,sort_order] = sort(predicted_iou(:,oi));
        local_average_iou = local_stat( d.IOUs_with_each_gt_obj(sort_order,oi), 2000); 
        local_p_over_50 = local_stat( double(d.IOUs_with_each_gt_obj(sort_order,oi) > .5), 2000); 
        
       
        
%         % hist of neg
%         subplot_lazy(6,1); hist( predicted_iou( d.IOUs_with_each_gt_obj(:,oi) <.5, oi ), 50 ); xlim([-.5 1.5]); title({cur_obj_str,'p(cx|~x)'}); xlabel('cx'); ylabel('frequency');
%         
%         % hist of pos
%         subplot_lazy(6,2); hist( predicted_iou( d.IOUs_with_each_gt_obj(:,oi) >.5, oi ), 50 ); xlim([-.5 1.5]); title('p(cx|x)'); xlabel('cx');
%         

        figure('color','white');

        % overlapping hists
        subplot_lazy(5,1);
        temp_x = [predicted_iou( d.IOUs_with_each_gt_obj(:,oi) <.5, oi ); predicted_iou( d.IOUs_with_each_gt_obj(:,oi) >.5, oi )];
        temp_y = [false(size(predicted_iou( d.IOUs_with_each_gt_obj(:,oi) <.5, oi ))); true(size(predicted_iou( d.IOUs_with_each_gt_obj(:,oi) >.5, oi )))];
        histn(temp_x,temp_y,100);
        xlabel('c_x');
        ylabel('count');
        legend('IOU_{gt} > .5','IOU_{gt} < .5');
        title(cur_obj_str)
        xlim([-.5 1.25])

        % ratio, empirical
        subplot_lazy(5,2);
        plot(bin_centers, p_cx_nx./p_cx_x);
        xlabel('c_x');
        ylabel('p(c_x|\negx) / p(c_x|x)');
        sum_abs_log_ratio(oi) = integral_est( bin_centers, abs(log(p_cx_nx./p_cx_x)) );
        xlim([-.5 1.25])
        
        % log ratio, empirical
        subplot_lazy(5,3);
        plot(bin_centers, log(p_cx_nx./p_cx_x));
        xlabel('c_x');
        ylabel('log( p(cx\negx) / p(cx|x) )');
        sum_abs_log_ratio(oi) = integral_est( bin_centers, abs(log(p_cx_nx./p_cx_x)) );
        xlim([-.5 1.25])

        
        % local p(gt > .5)
        subplot_lazy(5,4);
        plot( predicted_iou_sorted, local_p_over_50, '.' );
        xlabel('c_x');
        ylabel('p( IOU_{gt}>.5 )')
        xlim([-.5 1.25])
        legend(['empirical using training boxes']);
        ylim([0 1]);
        
         
        % p(x) | c_x
        subplot_lazy(5,5);
        pxs = [.001 .01 .1 .5];
        p_x_cx_func = nan(length(pxs),numel(p_cx_x));
        for pxi = 1:length(pxs)
            p_x = pxs(pxi);
            p_x_cx_func(pxi,:) = (p_cx_x * p_x) ./ (p_cx_x*p_x + p_cx_nx*(1-p_x) );
        end
        plot(bin_centers, p_x_cx_func);
        legend( cellfun(@(x) ['p(x) = ' num2str(x)],num2cell(pxs),'UniformOutput',false), 'location','northwest' );
        xlabel('classifier output');
        ylabel('p(x|c_x)');
        axis([-.5 1.25 0 1]);
        
        
        
        
        
         
    end
    
    

    
    
    
    
    
    
    
    %% total support func
    external_support = cell(1,numel(situation_struct.situation_objects));
    for oi = 1:numel(situation_struct.situation_objects)
        external_support{oi} = ext_sup_f(densities{oi},b_out);
    end
    
    hist( reshape(external_support{oi}(:,2:end),1,[]), 100)
    
    
    
    
    
    
    
    
    