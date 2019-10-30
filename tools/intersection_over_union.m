
function iou = intersection_over_union(A,B,format_A,format_B)

    % iou = intersection_over_union(A,B,format_A,format_B);
    %
    % assumes whole valued inds, with starting values at pixel start and ending vals at pixel end.
    % if you want to treat the values as continuous, ignoring pixel round-off, use
    %   intersection_over_union_continuous(A,B,format_A,format_B)
    %
    % if 2 args, each row of A is intersected with each row of B
    % if 1 arg, then each row is intersected with each row
    %
    % if A is 2 rows, and B is 3 rows, iou will be 2x3
    %
    % format1, format2 can be 'xywh' or 'r0rfc0cf'
    % if only format1 is provided, boxes A and B are assumed to have the
    % same format.
    % if neither is provided, then the format is assumed to be 'xywh'
    %
    % intersection_over_union(A_xywh,[],'xywh')
    % intersection_over_union(A_xywh,B_xywh,'xywh')
    % intersection_over_union(A_xywh,B_r0rfc0cf,'xywh','r0rfc0cf')
    %
    % see also intersection_over_union_continuous
   
    if nargin < 4

        if ~exist('format_A','var') || isempty(format_A)
            format_A = 'xywh';
        end

        % if only A is provided, run against itself
        if (~exist('B','var') || isempty(B)) && numel(A) > 4
            iou = intersection_over_union( A, A, format_A, format_A );
            return;
        end

        % then we must have B, so make sure it has a format
        if ~exist('format_B','var') || isempty(format_B)
            format_B = format_A;
        end
        
    end

    % if there are multiple boxes in A and/or B, run each against each
    if size(A,1) > 1 || size(B,1) > 1
        iou = zeros( size(A,1), size(B,1) );
        for ai = 1:size(A,1)
        for bi = 1:size(B,1)
            iou(ai,bi) = intersection_over_union( A(ai,:), B(bi,:), format_A, format_B );
        end
        end
        return
    end
    
    % now we should be to a single box for A and B
    switch format_A
        case 'xywh'
            xa=A(1); ya=A(2); wa=A(3); ha=A(4);
            r0a=ya; rfa=ya+ha-1; c0a=xa; cfa=xa+wa-1;
        case 'r0rfc0cf'
            r0a=A(1); rfa=A(2); c0a=A(3); cfa=A(4);
        otherwise
            error('unrecognized box format');
    end
    switch format_B
        case 'xywh'
            xb=B(1); yb=B(2); wb=B(3); hb=B(4);
            r0b=yb; rfb=yb+hb-1; c0b=xb; cfb=xb+wb-1;
        case 'r0rfc0cf'
            r0b=B(1); rfb=B(2); c0b=B(3); cfb=B(4);
        otherwise
            error('unrecognized box format');
    end
           
    intersect_area = intersection_area( [r0a rfa c0a cfa], [r0b rfb c0b cfb]);
    union_area = (cfa-c0a+1)*(rfa-r0a+1) + (cfb-c0b+1)*(rfb-r0b+1) - intersect_area;
    iou = intersect_area / union_area;
        
end




function area = intersection_area( boxA, boxB )

    % box format [r0 rf c0 cf];

    r0a = boxA(1);
    rfa = boxA(2);
    c0a = boxA(3);
    cfa = boxA(4);

    r0b = boxB(1);
    rfb = boxB(2);
    c0b = boxB(3);
    cfb = boxB(4);

    intersect_r = min(rfa,rfb) - max(r0a,r0b) + 1;
    intersect_c = min(cfa,cfb) - max(c0a,c0b) + 1;
    if intersect_r > 0 && intersect_c > 0
        area = intersect_r * intersect_c;
    else
        area = 0;
    end

end




