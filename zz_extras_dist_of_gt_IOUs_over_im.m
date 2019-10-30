% what is the distribution of IOU scores with a ground truth object over several images?

image_label = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_train/';
situation_struct = situate.situation_struct_load_all();
situation_struct = situation_struct.dogwalking;

ooi = 'leash';

im_lb = situate.labl_load(image_label,situation_struct);

hits  = nan(1,numel(im_lb));
total = nan(1,numel(im_lb));
for imi = 1:length(im_lb)
    
    cur_lb = im_lb(imi);
    ooii = strcmp( cur_lb.labels_adjusted,ooi);
    
    gt_box_r0rfc0cf = cur_lb.boxes_r0rfc0cf(ooii,:);

    box_w = gt_box_r0rfc0cf(4) - gt_box_r0rfc0cf(3);
    box_h = gt_box_r0rfc0cf(2) - gt_box_r0rfc0cf(1);
    step_ratio = 1/10;
    step = round(step_ratio * box_w);

    r0s = round( linspace( 1, cur_lb.im_h - box_h + 1, round(cur_lb.im_h/step) ) )';
    c0s = round( linspace( 1, cur_lb.im_w - box_w + 1, round(cur_lb.im_w/step) ) )';

    num_r0s = numel(r0s);
    
    r0s = sort(repmat(r0s,length(c0s),1));
    c0s = repmat(c0s,num_r0s,1);
    rfs = r0s + box_h - 1;
    cfs = c0s + box_w - 1;

    boxes_r0rfc0cf = [r0s rfs c0s cfs];

    ious = intersection_over_union( boxes_r0rfc0cf, gt_box_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );

%     accumulation_map = zeros(im_lb.im_h,im_lb.im_w);
%     for bi = 1:length(ious)
%         r0 = boxes_r0rfc0cf(bi,1);
%         rf = boxes_r0rfc0cf(bi,2);
%         c0 = boxes_r0rfc0cf(bi,3);
%         cf = boxes_r0rfc0cf(bi,4);
%         accumulation_map(r0:rf,c0:cf) = accumulation_map(r0:rf,c0:cf) + ious(bi);
%     end
% 
%     figure;
%     subplot(1,2,1); hist( ious, 10 );
%     subplot(1,2,2); imshow( accumulation_map, [] );

    
    hits(imi) = sum( ious >= .5 );
    total(imi) = numel(ious);
   
    progress(imi,numel(im_lb));
    
end



