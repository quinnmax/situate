
im = .75 * ones(400,600,3);
im_r = size(im,1);
im_c = size(im,2);
im_area = im_r * im_c;

area_ratio_min = (32*32)/im_area;

n = 9;
box_aspect_ratios = 2.^(linspace( log2(1/4), log2(4), n ));
box_area_ratios = 2.^(linspace( log2(1/64), log2(1/1), n ));
box_area_ratios = box_area_ratios(1:end-1);
box_area_ratios( box_area_ratios < area_ratio_min) = [];

overlap_ratio = .8;

[box_pool_r0rfc0cf, params] = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );

bp_w = box_pool_r0rfc0cf(:,4)-box_pool_r0rfc0cf(:,3) + 1;
bp_h = box_pool_r0rfc0cf(:,2)-box_pool_r0rfc0cf(:,1) + 1;
bp_rc = round(box_pool_r0rfc0cf(:,1) + bp_h/2 + .5);
bp_cc = round(box_pool_r0rfc0cf(:,3) + bp_w/2 + .5);
bp_aspect_ratio = bp_w ./ bp_h;
bp_area_ratio = (bp_w .* bp_h) / im_area;

% init boxes
good_init_boxes_aspect =  (bp_aspect_ratio > .5 & bp_aspect_ratio < .9) | ( bp_aspect_ratio > 1.1 & bp_aspect_ratio < 1.5 );
good_init_boxes_area =  ( bp_area_ratio > .05 & bp_area_ratio < .1 ) | (bp_area_ratio > .2 & bp_area_ratio < .3);
good_init_pool_inds = find(good_init_boxes_aspect & good_init_boxes_area );
init_pool_inds = good_init_pool_inds(randperm( numel(good_init_pool_inds), 200 ));

figure; imshow(im); hold on;
draw_box( box_pool_r0rfc0cf(init_pool_inds,:), 'r0rfc0cf' );
hold off;

n = 12;
times = nan(1,n);
figure;
for i = 1:n
    tic
    bi = randperm(size(box_pool_r0rfc0cf,1),1);
    cur_box_r0rfc0cf = box_pool_r0rfc0cf( bi, : );
    cur_aspect = bp_aspect_ratio(bi);
    cur_area = bp_area_ratio(bi);
    cur_rc = bp_rc( bi );
    cur_cc = bp_cc( bi );
    cur_w = bp_w( bi );
    cur_h = bp_h( bi );
    
    bp_aspect_ratio(bi) = 0;
    bp_area_ratio(bi) = 0;
    
    possible_inds = find( ...
          bp_aspect_ratio < cur_aspect*sqrt(2) ...
        & bp_aspect_ratio > cur_aspect/sqrt(2) ...
        & bp_area_ratio < cur_area*sqrt(2) ...
        & bp_area_ratio > cur_area/sqrt(2) ...
        & cur_rc < bp_rc + im_r/4 ...
        & cur_rc > bp_rc - im_r/4 ...
        & cur_cc < bp_cc + im_c/4 ...
        & cur_cc > bp_cc - im_c/4 );
    
    if numel(possible_inds) == 0
        possible_inds = true(size(bp_aspect_ratio));
    end
        
    cur_ious = intersection_over_union( cur_box_r0rfc0cf, box_pool_r0rfc0cf(possible_inds,:) );
    nearest_i = argmax(cur_ious);
    bi_est = possible_inds(nearest_i);
    
    times(i) = toc;
    progress(i,n);
    
    subplot_lazy(n,i);
    imshow(im); hold on;
    draw_box(box_pool_r0rfc0cf(possible_inds(cur_ious>prctile(cur_ious,95)),:),'r0rfc0cf','green');
    draw_box(box_pool_r0rfc0cf(possible_inds(argmax(cur_ious)),:),'r0rfc0cf','red');
    draw_box(cur_box_r0rfc0cf,'r0rfc0cf','blue');
    hold off;
    
end

figure;
hist(times);

































