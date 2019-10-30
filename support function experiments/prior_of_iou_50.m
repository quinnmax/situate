

% conclusion, probabilty of a bounding box having an iou over .5 is about half of one percent, if we go down to . often
% less. This is over a range of ground truth box sizes from 1 percent to 25 percent, and box
% proposals sampled from the same range, but with steps defined by their width. ie, there are more
% boxes that are small than boxes that are large.



% im bounds
im_r_min = -.5;
im_r_max =  .5;
im_c_min = -.5;
im_c_max =  .5;

% design
box_gt_areas       = (linspace(sqrt(.05),sqrt(.25),10)).^2;
box_proposal_areas = (linspace(sqrt(.05),sqrt(.25),10)).^2;
mean_ious  = nan(size(box_gt_areas));
zero_ratio = nan(size(box_gt_areas));
over_50    = nan(size(box_gt_areas));


use_correct_box_size = false;

% fixed box proposals
fixed_box_proposals_r0rfc0cf = [];
for bai = 1:numel(box_proposal_areas)
    bw = sqrt(box_proposal_areas(bai));
    display(bw)
    steps = ceil(10 * (im_r_max - im_r_min - bw) / bw);
    display(steps)
    r0s = linspace(im_r_min,im_r_max-bw,steps)';
    rfs = r0s + bw;
    c0s = linspace(im_c_min,im_c_max-bw,steps)';
    cfs = c0s + bw;

    rep_rs = sortrows(repmat([r0s rfs],numel(c0s),1));
    rep_cs = repmat(sortrows([c0s cfs]),numel(r0s),1);

    temp_boxes_r0rfc0cf = [rep_rs rep_cs];
    fixed_box_proposals_r0rfc0cf = [fixed_box_proposals_r0rfc0cf; temp_boxes_r0rfc0cf];
end

fixed_box_proposals_area = (fixed_box_proposals_r0rfc0cf(:,2)-fixed_box_proposals_r0rfc0cf(:,1)) ...
                        .* (fixed_box_proposals_r0rfc0cf(:,4)-fixed_box_proposals_r0rfc0cf(:,3));



for bai = 1:numel(box_gt_areas)

    % gt box

    box_gt_area = box_gt_areas(bai);
    bw = sqrt(box_gt_area);

    bgt_r0 = im_r_min + rand()*(im_r_max-im_r_min-bw);
    bgt_c0 = im_c_min + rand()*(im_c_max-im_c_min-bw);
    bgt_rf = bgt_r0 + bw;
    bgt_cf = bgt_c0 + bw;

%     bgt_r0 = 0 - bw/2;
%     bgt_c0 = 0 - bw/2;
%     
%     bgt_rf = bgt_r0 + bw;
%     bgt_cf = bgt_c0 + bw;
    
    box_gt_r0rfc0cf = [bgt_r0 bgt_rf bgt_c0 bgt_cf];

    if use_correct_box_size
        % dynamic box proposals (ie, correct box size)
        n = 100;
        r0s = linspace(im_r_min,im_r_max-bw,n)';
        rfs = r0s + bw;
        c0s = linspace(im_c_min,im_c_max-bw,n)';
        cfs = c0s + bw;

        rep_rs = sortrows(repmat([r0s rfs],numel(c0s),1));
        rep_cs = repmat(sortrows([c0s cfs]),numel(r0s),1);

        boxes_r0rfc0cf = [rep_rs rep_cs];
    else
        boxes_r0rfc0cf = fixed_box_proposals_r0rfc0cf;
    end
    
    % ious

    box_ious =  intersection_over_union_continuous( boxes_r0rfc0cf, box_gt_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
    
    mean_ious(bai) = mean(box_ious);
    zero_ratio(bai) = mean( box_ious == 0 );
    over_50(bai) = mean( box_ious >= .5 );
    
    fprintf('.');
    
end

figure;
    subplot(1,3,1);
    plot( box_gt_areas, mean_ious );
    xlabel('gt box area'); ylabel('mean iou');
    ylim([0 1]);
    
    subplot(1,3,2);
    plot( box_gt_areas, zero_ratio );
    xlabel('gt box area'); ylabel('zero iou ratio');
    ylim([0 1]);
    
    subplot(1,3,3);
    plot( box_gt_areas, (over_50));
    xlabel('gt box area'); ylabel('over .5 iou ratio');
    ylim([0 .10]);
















