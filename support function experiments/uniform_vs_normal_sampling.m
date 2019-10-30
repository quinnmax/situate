


model_uniform = situation_models.uniform_fit();
model_normal  = load('/Users/Max/Dropbox/Projects/situate/saved_models/dogwalkerdogleash, normal situation model, 0.mat');

fnames = cellfun( @(x) ...
        ['/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/' x '.json'], ...
        model_normal.fnames_lb_train,'UniformOutput',false);

temp = situate.situation_struct_load_all();
situation_struct = temp.dogwalking;
    
num_objs = numel(situation_struct.situation_objects);

density_uniform_sampled_normal_scored = [];
density_normal_sampled_normal_scored = [];
density_normal_sampled_conditional2_scored = [];
density_conditioned_2_sampled_conditioned_2_scored = [];
density_conditioned_1a_sampled_conditioned_1a_scored = [];
density_conditioned_1b_sampled_conditioned_1b_scored = [];
density_uniform_sampled_conditional2_scored = [];

density_conditioned_1a_sampled_normal_scored = [];
density_conditioned_1b_sampled_normal_scored = [];
density_conditioned_2_sampled_normal_scored  = [];

ious_uniform = [];
ious_normal  = [];
ious_conditioned_2  = [];
ious_conditioned_1a = [];
ious_conditioned_1b = [];

uniform_boxes_area_ratio = [];
uniform_boxes_aspect_ratio = [];
uniform_boxes_normalized_xc_yc = [];


ooi = [];
for imi = 1:numel(fnames)
    
    cur_labl = situate.labl_load( fnames{imi}, situation_struct );
    im_row = cur_labl.im_h;
    im_col = cur_labl.im_w;
    n = 500;
    
    [workspaces_dummy, detected_object_matrix] = make_dummy_workspaces( cur_labl, situation_struct );

    for oi = 1:3
        
        % object of interest
        ooi = [ooi; repmat( oi, n, 1) ];
        object_type = situation_struct.situation_objects{oi};
        
        % get gt box
        li = find( strcmp( object_type, cur_labl.labels_adjusted) );
        cur_gt_box_r0rfc0cf = cur_labl.boxes_r0rfc0cf(li,:);
        
        % build conditioning models
            other_obj_inds = setsub(1:num_objs,oi);
            % obj 1a
            workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) & ~logical(detected_object_matrix(:,other_obj_inds(1))) &  logical(detected_object_matrix(:,other_obj_inds(2)));
            model_conditional_1a_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );
            % obj 1b
            workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) &  logical(detected_object_matrix(:,other_obj_inds(1))) & ~logical(detected_object_matrix(:,other_obj_inds(2)));
            model_conditional_1b_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );
            % objs 2
            workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) &  logical(detected_object_matrix(:,other_obj_inds(1))) &  logical(detected_object_matrix(:,other_obj_inds(2)));
            model_conditional_2_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );
            
            
            
            
            
        % Uniform samples
        [boxes_r0rfc0cf_uniform, uniform_density] = situation_models.uniform_sample( model_uniform, object_type, n, [im_row im_col]); 
        w = boxes_r0rfc0cf_uniform(:,4) - boxes_r0rfc0cf_uniform(:,3);
        h = boxes_r0rfc0cf_uniform(:,2) - boxes_r0rfc0cf_uniform(:,1);
        cur_area_ratios = (w.*h) / (im_row * im_col);
        cur_aspect_ratios = w./h;
        lsf = 1/ sqrt( im_row * im_col);
        cur_xc = lsf * (( boxes_r0rfc0cf_uniform(:,3) + w/2 ) - im_col/2);
        cur_yc = lsf * (( boxes_r0rfc0cf_uniform(:,1) + h/2 ) - im_row/2);
        uniform_boxes_area_ratio = [uniform_boxes_area_ratio; cur_area_ratios];
        uniform_boxes_aspect_ratio = [uniform_boxes_aspect_ratio; cur_aspect_ratios];
        uniform_boxes_normalized_xc_yc = [uniform_boxes_normalized_xc_yc; [cur_xc cur_yc] ];
        
        
        
        
        
        % Normal samples, Normal scores
        [boxes_r0rfc0cf_normal, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col]); 
        density_normal_sampled_normal_scored = [density_normal_sampled_normal_scored; temp];
        
        % Conditional 1a samples, Conditional 1a scores
        [boxes_r0rfc0cf_conditioned_1a, temp] = situation_models.normal_sample( model_conditional_1a_dummy, object_type, n, [im_row im_col]); 
        density_conditioned_1a_sampled_conditioned_1a_scored = [density_conditioned_1a_sampled_conditioned_1a_scored; temp];
        
        % Conditional 1b samples, Conditional 1b scores
        [boxes_r0rfc0cf_conditioned_1b, temp] = situation_models.normal_sample( model_conditional_1b_dummy, object_type, n, [im_row im_col]); 
        density_conditioned_1b_sampled_conditioned_1b_scored = [density_conditioned_1b_sampled_conditioned_1b_scored; temp];
        
        % Conditional 2 samples, Conditional 2 scores
        [boxes_r0rfc0cf_conditioned_2, temp] = situation_models.normal_sample( model_conditional_2_dummy, object_type, n, [im_row im_col]); 
        density_conditioned_2_sampled_conditioned_2_scored = [density_conditioned_2_sampled_conditioned_2_scored; temp];
        
     
        
        
        
        % Uniform samples, Normal scores
        [~, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col], boxes_r0rfc0cf_uniform); 
        density_uniform_sampled_normal_scored = [density_uniform_sampled_normal_scored; temp];
        
        % Uniform samples, Conditional scores
        [~, temp] = situation_models.normal_sample( model_conditional_2_dummy, object_type, n, [im_row im_col], boxes_r0rfc0cf_uniform); 
        density_uniform_sampled_conditional2_scored = [density_uniform_sampled_conditional2_scored; temp];
        
        % Normal samples, Conditional2 scores
        [~, temp] = situation_models.normal_sample( model_conditional_2_dummy, object_type, n, [im_row im_col], boxes_r0rfc0cf_normal); 
        density_normal_sampled_conditional2_scored = [density_normal_sampled_conditional2_scored; temp];
        
        
        % Conditional 1a samples, normal scores
        [~, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col], boxes_r0rfc0cf_conditioned_1a); 
        density_conditioned_1a_sampled_normal_scored = [density_conditioned_1a_sampled_normal_scored; temp];
        
        % Conditional 1b samples, normal scores
        [~, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col], boxes_r0rfc0cf_conditioned_1b); 
        density_conditioned_1b_sampled_normal_scored = [density_conditioned_1b_sampled_normal_scored; temp];
        
        % Conditional 2 samples, normal scores
        [~, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col], boxes_r0rfc0cf_conditioned_2); 
        density_conditioned_2_sampled_normal_scored = [density_conditioned_2_sampled_normal_scored; temp];
        
        
        
        
        
        % get gt iou of uniform samples
        temp = intersection_over_union( boxes_r0rfc0cf_uniform, cur_gt_box_r0rfc0cf,'r0rfc0cf','r0rfc0cf' );
        ious_uniform = [ious_uniform; temp];
        
        % get gt iou of normal samples
        temp = intersection_over_union( boxes_r0rfc0cf_normal, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
        ious_normal = [ious_normal; temp];
        
        % get gt iou of conditioned samples samples
        temp = intersection_over_union( boxes_r0rfc0cf_conditioned_1a, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
        ious_conditioned_1a = [ious_conditioned_1a; temp];
        
        temp = intersection_over_union( boxes_r0rfc0cf_conditioned_1b, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
        ious_conditioned_1b = [ious_conditioned_1b; temp];
        
        temp = intersection_over_union( boxes_r0rfc0cf_conditioned_2, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
        ious_conditioned_2 = [ious_conditioned_2; temp];
        
        
        
        
    end
    
    progress(imi,numel(fnames));
    
end

%% visual of uniform dist w/wo iou>.5

for oi = 1:3

    figure;
    subplot2(3,3,1,1);
    hist(uniform_boxes_normalized_xc_yc(ooi==oi,:),100);
    subplot2(3,3,1,2);
    hist(uniform_boxes_normalized_xc_yc( ious_uniform<.5 & ooi==oi,:),100);
    subplot2(3,3,1,3);
    hist(uniform_boxes_normalized_xc_yc( ious_uniform>.5 & ooi==oi,:),100);

    subplot2(3,3,2,1);
    hist(log(uniform_boxes_area_ratio(ooi==oi)),100);
    subplot2(3,3,2,2);
    hist(log(uniform_boxes_area_ratio( ious_uniform<.5 & ooi==oi)),100);
    subplot2(3,3,2,3);
    hist(log(uniform_boxes_area_ratio( ious_uniform>.5 & ooi==oi)),100);

    subplot2(3,3,3,1);
    hist(log(uniform_boxes_aspect_ratio(ooi==oi)),100);
    subplot2(3,3,3,2);
    hist(log(uniform_boxes_aspect_ratio( ious_uniform<.5 & ooi==oi)),100);
    subplot2(3,3,3,3);
    hist(log(uniform_boxes_aspect_ratio( ious_uniform>.5 & ooi==oi)),100);

end



%% mean iou, corr coeff of densities

big_cell = {};

methods = {
    'uniform sampling, normal density',...
    'normal sampling, normal density',...
    'normal sampling, conditional density',...
    'conditional 2 sampling, conditional 2 density'};
methods{end+1} = 'others combined';    
% 'conditional 1a sampling, conditional 1a density', ...
% 'conditional 1b sampling, conditional 1b density', ...
    

iou_sources = { ious_uniform, ...
                ious_normal, ...
                ious_normal, ...
                ious_conditioned_2 };
iou_sources{end+1} = vertcat(iou_sources{:});
% ious_conditioned_1a, ...
% ious_conditioned_1b, ...
                
      
score_sources = {density_uniform_sampled_normal_scored;...
                 density_normal_sampled_normal_scored;...
                 density_normal_sampled_conditional2_scored; ...
                 density_conditioned_2_sampled_conditioned_2_scored };
score_sources{end+1} = vertcat( score_sources{:});
% density_conditioned_1a_sampled_conditioned_1a_scored; ...
% density_conditioned_1b_sampled_conditioned_1b_scored; ...
                 
  
obj_indexing = { ooi; ...
                 ooi; ...
                 ooi; ...
                 ooi };
obj_indexing{end+1} = vertcat(obj_indexing{:});
% ooi; ...
% ooi; ...
                 



rpm = 4; %rows_needed_per_method

do_big_cell = false;

if do_big_cell

        for oi = 1:num_objs

            big_cell{1,oi+1} = situation_struct.situation_objects{oi};

            for mi = 1:numel(methods)

                big_cell{(mi-1)*rpm+2,1} = ['\textbf{' methods{mi} '}'];
                big_cell{(mi-1)*rpm+3,1} = 'mean IOU';
                big_cell{(mi-1)*rpm+4,1} = '$p\big( IOU(x) > .5 \big)$';
                big_cell{(mi-1)*rpm+5,1} = 'AUROC';

                tempx = score_sources{mi}(obj_indexing{mi}==oi);
                tempy = iou_sources{mi}(obj_indexing{mi}==oi) > .5;

                big_cell{(mi-1)*rpm+3,oi+1} = mean(iou_sources{mi}(obj_indexing{mi}==oi));
                big_cell{(mi-1)*rpm+4,oi+1} = mean( tempy >= .5 );
                big_cell{(mi-1)*rpm+5,oi+1} = ROC( tempx(1:20:end), tempy(1:20:end) );

                fprintf('.');

            end

            fprintf('\n');

        end

        oi = num_objs + 1;
        big_cell{1,oi+1} = 'all';

        for mi = 1:numel(methods)

            tempx = score_sources{mi};
            tempy = iou_sources{mi} > .5;

            big_cell{(mi-1)*rpm+3,oi+1} = mean(iou_sources{mi});
            big_cell{(mi-1)*rpm+4,oi+1} = mean( tempy >= .5 );
            big_cell{(mi-1)*rpm+5,oi+1} = ROC( tempx(1:100:end), tempy(1:100:end) );

            fprintf('.');

        end

        latex_print(big_cell);

end
        

%% figure out p(x|bx,y,by)


densities = score_sources{end};
%densities = densities(numel(densities)*.25+1:end); 

ious = iou_sources{end};
%ious = ious(numel(ious)*.25+1:end); 
  
ooi_inds = obj_indexing{end};
%ooi_inds = ooi_inds(numel(ooi_inds)*.25+1:end); 
  
% pxs = [mean(ious(ooi==1)>.5) mean(ious(ooi==2)>.5) mean(ious(ooi==3)>.5)];
% bxs = [mean(densities(ooi==1)) mean(densities(ooi==2)) mean(densities(ooi==3))];
% px = nan(size(densities));
% bx = nan(size(densities));
% for oi = 1:num_objs
%     px(ooi==oi) = pxs(oi);
%     bx(ooi==oi) = bxs(oi);
% end

%px = .01;
%bx = mean(densities);
%pxbxyby = 1 ./ (1 + exp( -log(densities) - log(px) + log(1-px) + log(bx)  ));

pxbxyby = nan(size(densities));
bx = nan(1,num_objs);
px = nan(1,num_objs);
for oi = 1:num_objs
    ci = ooi_inds == oi;
    bx(oi) = prctile(densities(ci),50);
    %bx(oi) = prctile(densities(ci),75);
    %bx(oi) = prctile(densities(ci),80);
    %bx(oi) = mean(densities(ci));
    %bx(oi) = prctile(densities(ci),62.5);
    px(oi) = mean(ious(ci)>.5);
    pxbxyby(ci) = 1 ./ (1 + exp( -log(densities(ci)) - log(px(oi)) + log(1-px(oi)) + log(bx(oi))  ));
end


bin_p = nan(num_objs,n);
bin_mean_iou = nan(num_objs,n);
bin_count = zeros(num_objs,n);
for oi = 1:num_objs
    
    ci = ooi_inds == oi;
    cur_px = pxbxyby(ci);
    cur_iou = ious(ci);
    
    
    n = 10;
    [assignments,~,bin_centers] = bin_linear( cur_px, linspace(0,1,n+1) );
    
    for bi = 1:n
        bin_p(oi,bi) = mean( cur_iou( assignments == bi )> .5 );
        bin_mean_iou(oi,bi) = mean( cur_iou( assignments == bi ) );
        bin_count(oi,bi) = sum( assignments == bi );
    end
    
   
end

figure('color','white');

for oi = 1:num_objs
    subplot2(4,num_objs,1,oi); 
    bar( bin_centers, bin_count(oi,:) );
    xlim([0,1]);
    ylim([0 1.1*max(bin_count(:))]);
    xlabel('p(x|bx,y,by) predicted'); 
    ylabel('data freq'); 
    title(situation_struct.situation_objects{oi});
  
    subplot2(4,num_objs,2,oi);
    plot( bin_centers, bin_p(oi,:));
    xlim([0,1]);
    ylim([0,.5]);
    xlabel('p(x|bx,y,by) predicted');
    ylabel('p(x|bx,y,by) actual');
    
    subplot2(4,num_objs,3,oi);
    plot( bin_centers, bin_mean_iou(oi,:));
    xlim([0,1]);
    ylim([0,.5]);
    xlabel('p(x|bx,y,by) predicted');
    ylabel('mean IOU');
    
    subplot2(4,num_objs,4,oi);
    ci = find(ooi_inds == oi);
    ci = ci(1:100:end);
    plot( pxbxyby(ci), ious(ci),'.');
    xlabel('p(x|bx,y,by) predicted');
    ylabel('gt IOU');
    xlim([0 1]);
    ylim([0 1]);
end






%% appropriate scaling

% find cdf params


pxbxyby_cdf_param = nan( num_objs, 2 );
pxbxyby_a_param = nan(num_objs,1);
external_support = nan(size(pxbxyby));
for oi = 1:num_objs
    
    use_beta = true;
    
    if use_beta
        pxbxyby_cdf_param(oi,:) = betafit( pxbxyby( ooi_inds==oi ) );
        cur_exp_sup = betacdf( pxbxyby( ooi_inds==oi ), pxbxyby_cdf_param(oi,1), pxbxyby_cdf_param(oi,2) );
        external_support( ooi_inds==oi ) = cur_exp_sup;
    else
        cur_param = expfit( pxbxyby( ooi_inds==oi ) );
        cur_exp_sup = expcdf( pxbxyby( ooi_inds==oi ), cur_param );
        external_support( ooi_inds==oi ) = cur_exp_sup;
    end
    
end




% repeat with external support

bin_p = nan(num_objs,n);
bin_mean_iou = nan(num_objs,n);
bin_count = zeros(num_objs,n);
for oi = 1:num_objs
    
    ci = ooi_inds == oi;
    cur_exp_sup = external_support(ci);
    cur_iou = ious(ci);
    
    
    n = 10;
    [assignments,~,bin_centers] = bin_linear( cur_exp_sup, linspace(0,1,n+1) );
    
    for bi = 1:n
        bin_p(oi,bi) = mean( cur_iou( assignments == bi )> .5 );
        bin_mean_iou(oi,bi) = mean( cur_iou( assignments == bi ) );
        bin_count(oi,bi) = sum( assignments == bi );
    end
    
   
end

figure('color','white');

for oi = 1:num_objs
    subplot2(4,num_objs,1,oi); 
    bar( bin_centers, bin_count(oi,:) );
    xlim([0,1]);
    ylim([0 1.1*max(bin_count(:))]);
    xlabel('external support'); 
    ylabel('data freq'); 
    title(situation_struct.situation_objects{oi});
  
    subplot2(4,num_objs,2,oi);
    plot( bin_centers, bin_p(oi,:));
    xlim([0,1]);
    ylim([0,.5]);
    xlabel('external support');
    ylabel('p(x|bx,y,by) actual');
    
    subplot2(4,num_objs,3,oi);
    plot( bin_centers, bin_mean_iou(oi,:));
    xlim([0,1]);
    ylim([0,.5]);
    xlabel('external support');
    ylabel('mean IOU');
    
    subplot2(4,num_objs,4,oi);
    ci = find(ooi_inds == oi);
    ci = ci(1:100:end);
    plot( external_support(ci), ious(ci),'.');
    xlabel('external support');
    ylabel('gt IOU');
    xlim([0 1]);
    ylim([0 1]);
end







