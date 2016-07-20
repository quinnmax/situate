


function b_out = box_format_conversion( b, format_in, format_out )



    % b_out = box_format_conversion( b_in, format_in, format_out );
    %
    % format options:
    %   r0rfc0cf, row start, row end, column start, column end
    %   r0c0rfcf, row start, column start, row end, column end
    %   xywh, x start, y start, width, height
    %   xcycwh - x center, y center, width, height
    %
    % be careful going between xy stuff and rc stuff. if you go from xy to
    % rc, I assume you were talking about pixels to start with and do some
    % whole value corrections. if you stay in rc or stay in xy, things
    % should be fine.
   
    
    
    switch format_in
        case 'r0rfc0cf'
            r0 = b(:,1);
            rf = b(:,2);
            c0 = b(:,3);
            cf = b(:,4);
            x = c0;
            y = r0;
            w = cf - c0 + 1; 
            h = rf - r0 + 1;
        case 'r0c0rfcf'
            r0 = b(:,1);
            rf = b(:,3);
            c0 = b(:,2);
            cf = b(:,4);
            x = c0;
            y = r0;
            w = cf - c0 + 1; 
            h = rf - r0 + 1;
        case 'xywh'
            r0 = b(:,2);
            rf = r0 + b(:,4) - 1;
            c0 = b(:,1);
            cf = c0 + b(:,3) - 1;
            x = b(:,1);
            y = b(:,2);
            w = b(:,3);
            h = b(:,4);
        case 'xcycwh'
            r0 = b(:,2) - floor(b(:,4)/2);
            rf = r0 + b(:,4) - 1;
            c0 = b(:,1) - floor(b(:,3)/2);
            cf = c0 + b(:,3) - 1;
            x = b(:,1) - b(:,3)/2;
            y = b(:,2) - b(:,4)/2;
            w = b(:,3);
            h = b(:,4);
        otherwise
            error('box_format_conversion:unrecognized format_in');
    end

    

    switch format_out

        case 'r0rfc0cf'
            b_out = [r0 rf c0 cf];
        case 'r0c0rfcf'
            b_out = [r0 c0 rf cf];
        case 'xywh'
            b_out = [x y w h];
        case 'xcycwh'
            b_out = [x+w/2 y+w/2 w h];
        otherwise
            error('box_format_conversion:unrecognized format_out');
    end
    
    
    
%     if ( any( strcmp( format_in, {'r0rfc0cf','r0c0rfcf'} )) && any( strcmp( format_out, {'xywh','xcycwh'} )) ) || ...
%        ( any( strcmp( format_in, {'xywh','xcycwh'} ))       && any( strcmp( format_out, {'r0rfc0cf','r0c0rfcf'} )) )
%         warning('box_format_conversion between tricky types',['converting between ' format_in ' and ' format_out ' can have some unintended whole-value pixel weirdness']);
%     end
    
    
    
end
























