function box_out = box_super( boxes_in, format_in, format_out )

% box_out = box_super( boxes_in, [format_in], [format_out] );
% default format_in = format_out = 'r0rf0c0f';

    if ~exist('format_in') || isempty(format_in)
        format_in = 'r0rfc0cf';
    end
    
    if ~exist('format_out') || isempty(format_out)
        format_out = 'r0rfc0cf';
    end
    

    if (strcmp( format_in, 'r0rfc0cf' ) && strcmp( format_out, 'r0rfc0cf' ))

        r0 = min(boxes_in(:,1));
        rf = max(boxes_in(:,2));
        c0 = min(boxes_in(:,3));
        cf = min(boxes_in(:,4));

        box_out = [r0 rf c0 cf];
    
    else
        
        error('format support is not supported sport');
        
    end
    


    