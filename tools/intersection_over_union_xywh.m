
function iou = intersection_over_union_xywh(A,B)

    % iou = intersection_over_union_xywh(A,B);
    %
    % if 2 args, each row of A is intersected with each row of B
    % if 1 arg, then each row is intersected with each row
    %
    % if A is 2 rows, and B is 3 rows, iou will be 2x3

    if nargin == 2
        iou = zeros( size(A,1), size(B,1) );
        for ai = 1:size(A,1)
        for bi = 1:size(B,1)
            cur_A = A(ai,:);
            cur_B = B(bi,:);
            
            %intersection_area = rectint(cur_A,cur_B);
            r0a = cur_A(2);
            rfa = cur_A(2) + cur_A(4);
            c0a = cur_A(1);
            cfa = cur_A(1) + cur_A(3);
            r0b = cur_B(2);
            rfb = cur_B(2) + cur_B(4);
            c0b = cur_B(1);
            cfb = cur_B(1) + cur_B(3);
            intersection_area = intersect_mq( [r0a rfa c0a cfa], [r0b rfb c0b cfb]);
            
            union_area = cur_A(3)*cur_A(4) + cur_B(3)*cur_B(4) - intersection_area;
            cur_iou = intersection_area / union_area;
            iou(ai,bi) = cur_iou;
        end
        end
    end
    
    if nargin == 1 && numel(A) > 4
        iou = zeros( size(A,1) );
        for i = 1:size(A,1)
        for j = 1:size(A,1)
            cur_A = A(i,:);
            cur_B = A(j,:);
            
            %intersection_area = rectint(cur_A,cur_B);
            r0a = cur_A(2);
            rfa = cur_A(2) + cur_A(4);
            c0a = cur_A(1);
            cfa = cur_A(1) + cur_A(3);
            r0b = cur_B(2);
            rfb = cur_B(2) + cur_B(4);
            c0b = cur_B(1);
            cfb = cur_B(1) + cur_B(3);
            intersection_area = intersect_mq( [r0a rfa c0a cfa], [r0b rfb c0b cfb]);
            
            union_area = cur_A(3)*cur_A(4) + cur_B(3)*cur_B(4) - intersection_area;
            cur_iou = intersection_area / union_area;
            iou(i,j) = cur_iou;
        end
        end
    end
    
end



