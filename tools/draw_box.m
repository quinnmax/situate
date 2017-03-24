function h = draw_box(box, box_format, arg)

% h = draw_box(box, box_format, arg);
% box_format options include
%   'xywh'
%   'r0rfc0cf'
%   'xcycwh'
%   'c0cfr0rf'

    switch box_format
        case 'xywh'
            x  = box(:,1);
            y  = box(:,2);
            w  = box(:,3);
            h  = box(:,4);
            r0 = y;
            rf = y + h - 1;
            c0 = x;
            cf = x + w - 1;
        case 'r0rfc0cf'
            r0 = box(:,1);
            rf = box(:,2);
            c0 = box(:,3);
            cf = box(:,4);
        case 'xcycwh'
            xc = box(:,1); 
            yc = box(:,2); 
            w  = box(:,3); 
            h  = box(:,4);
            r0 = yc - h/2;
            rf = r0 + h - 1;
            c0 = xc - w/2;
            cf = c0 + w - 1;
        case 'c0cfr0rf'
            c0 = box(:,1);
            cf = box(:,2);
            r0 = box(:,3);
            rf = box(:,4);
        case 'c0r0cfrf'
            c0 = box(:,1);
            r0 = box(:,2);
            cf = box(:,3);
            rf = box(:,4);
        otherwise
            error('unrecogonized box_format');
    end
    
    for i = 1:size(box,1)

        cs = [c0(i) c0(i) cf(i) cf(i) c0(i)];
        rs = [r0(i) rf(i) rf(i) r0(i) r0(i)];

        if ~exist('arg','var') || isempty(arg)
            h = plot(cs, rs);
        elseif ischar(arg)
            h = plot(cs, rs, arg);
        elseif isnumeric(arg) && length(arg) == 3
            h = plot(cs, rs, 'Color', arg);
        end
        
    end
    
end

