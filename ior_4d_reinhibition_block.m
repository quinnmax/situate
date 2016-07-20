function x_out = ior_4d_reinhibition_block( x_size, domains, inhibition_widths, inhibition_intensity, r )

    % x_out = ior_4d_reinhibition_block( x_size, domains, inhibition_widths_px, inhibition_intensity, sampled_boxes_record_r0rfc0cf );
    %
    % x_size is the target size of the inhibition block
    % 
    % domains list the sampling spaces modeled in x. x has four dimensions,
    % so there should be domains specified in domains
    % 
    % inhibition_widths is how much inhibition to include in the block at
    % each specified point. the inhibition widths are in x units, not the
    % original domain units
    %
    % inhibition intensity defines how hard to inhibit at the specified
    % points. should be using 1 for this, as there's nothing stochastic
    % about a point in this space, so no reason to return to it.
    %
    % sampled_boxes_record_r0rfc0cf will be turned into points at which to
    % actually inhibit. as the domains might have changed since original
    % sampling, this wont' be a perfect 1:1 match. that is, the domain of
    % box shapes might have been the prior for much of the existing
    % sampling record, but is conditional now, so won't quite match. this
    % does make the inhibition a little weird, as the bounds of inhibition
    % have changed since original sampling.
    %
    % this created a confusing behavior at one point. many samples might have
    % been drawn, inhibiting the most likely box size in the prior, but
    % when the domain shifted, the new most likely size was pre-inhibited,
    % 

    x_out = ones(x_size);
    
    
    % convert the sampled box records to points in the domain
   %  warning('ior_4d_reinhibition_block only works for log2 aspect ratio and log10 area ratio for the time being');
    
    
    
    
    persistent h;
    if isempty('h') || length(inhibition_widths) ~= length(size(h)) || ~all( inhibition_widths == size(h) )
        temp1 = repmat( blackman(inhibition_widths(1)) * blackman(inhibition_widths(2))', 1,1,inhibition_widths(3),inhibition_widths(4) );
        temp2 = repmat( reshape(blackman(inhibition_widths(3)),1,1,[],1), inhibition_widths(1),inhibition_widths(2),1,inhibition_widths(4) );
        temp3 = repmat( reshape(blackman(inhibition_widths(4)),1,1,1,[]), inhibition_widths(1),inhibition_widths(2),inhibition_widths(3),1 );
        inhibition_mask_temp = temp1 .* temp2 .* temp3;
        h = 1 - ( inhibition_intensity * mat2gray(inhibition_mask_temp) );
    end
    
    for pi = 1:size(r,1)
    
        box_rows = r(pi,2) - r(pi,1) + 1;
        box_cols = r(pi,4) - r(pi,3) + 1;
        box_log2_aspect_ratio = log2(box_cols/box_rows);
        box_log10_area_ratio  = log10( (box_rows*box_cols) / (domains{1}(end)*domains{2}(end)) );
        box_row_center = r(pi,1) + .5 * box_rows;
        box_col_center = r(pi,3) + .5 * box_cols;
        
        [~,x_row] = min( abs( domains{1} - box_row_center ) );
        [~,x_col] = min( abs( domains{2} - box_col_center ) );
        [~,x_log2_aspect_ratio] = min( abs( domains{3} - box_log2_aspect_ratio ) );
        [~,x_log10_area_ratio]  = min( abs( domains{4} - box_log10_area_ratio ) );
        cur_point = [x_row, x_col, x_log2_aspect_ratio, x_log10_area_ratio];
        
        block_i0 = zeros(1,length(x_size));
        block_if = zeros(1,length(x_size));

        filt_i0 = zeros(1,length(x_size));
        filt_if = zeros(1,length(x_size));

        for di = 1:length(x_size)     % dimension index

            block_i0(di) = cur_point(di) - floor(inhibition_widths(di)/2);
            block_if(di) = block_i0(di) + inhibition_widths(di) - 1;

            if block_i0(di) < 1
                filt_i0(di) = 1 + (1-block_i0(di));
                block_i0(di) = 1;
            else
                filt_i0(di) = 1;
            end

            if block_if(di) > x_size(di)
                filt_if(di) = inhibition_widths(di) - (block_if(di) - x_size(di));
                block_if(di) = x_size(di);
            else
                filt_if(di) = inhibition_widths(di);
            end
        
        end
        
    x_out( ...
    block_i0(1):block_if(1), ...
    block_i0(2):block_if(2), ...
    block_i0(3):block_if(3), ...
    block_i0(4):block_if(4) ) = ...
        x_out( ...
            block_i0(1):block_if(1), ...
            block_i0(2):block_if(2), ...
            block_i0(3):block_if(3), ...
            block_i0(4):block_if(4) ) .* ...
        h( ...
            filt_i0(1):filt_if(1), ...
            filt_i0(2):filt_if(2), ...
            filt_i0(3):filt_if(3), ...
            filt_i0(4):filt_if(4) );
        
    end
            
end
                
    
        
    





