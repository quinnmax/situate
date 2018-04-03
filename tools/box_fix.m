function [ success, box_r0rfc0cf, box_xywh, box_xcycwh, aspect_ratio, area_ratio ] = box_fix( box, format_str, image_size )
% [ success, box_r0rfc0cf, box_xywh, box_xcycwh, aspect_ratio, area_ratio ] = box_fix( box, format_str, image_size );
% 
% this rounds off the box parameters, keeps them in image bounds, etc

    % process input boxes
        switch format_str
            case 'r0rfc0cf'
                r0 = box(:,1);
                rf = box(:,2);
                c0 = box(:,3);
                cf = box(:,4);
            case 'xywh'
                c0 = box(:,1);
                r0 = box(:,2);
                cf = box(:,1) + box(:,3) - 1;
                rf = box(:,2) + box(:,4) - 1;
            case 'xcycwh'
                c0 = box(:,1) - box(:,3)/2 + .5;
                cf = c0 + box(3) - 1;
                r0 = box(:,2) - box(:,4)/2 + .5;
                rf = r0 + box(:,4) - 1;
            otherwise
                error( 'don''t recognize format_str' );
        end
    
    % force box into bounds
        r0 = max( round(r0), 1 );
        rf = min( round(rf), image_size(1) );
        c0 = max( round(c0), 1 );
        cf = min( round(cf), image_size(2) );

    % filling out the parameters
        w  = cf - c0 + 1;
        h  = rf - r0 + 1;
        x  = c0;
        y  = r0;
        xc = round( x + w/2 - .5 );
        yc = round( y + h/2 - .5 );

    % build the output boxes
        box_r0rfc0cf = [ r0 rf c0 cf ];
        box_xywh     = [  x  y  w  h ];
        box_xcycwh   = [ xc yc  w  h ];

        aspect_ratio = w./h;
        area_ratio = ( w .* h ) ./ ( image_size(1) * image_size(2) );
        
    success = all( w > 0 ) && all( h > 0 );
            
end
            