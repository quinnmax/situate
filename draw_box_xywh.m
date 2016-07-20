
function h = draw_box_xywh(x,arg)

    % h = draw_box(x,'arg');
    %
    % x0,y0,x_delta,y_delta
    % or 
    % col_0,row_0,num_cols,num_rows
    %
    % to make it line up correctly with pixels, add .5 to x and y

    
    if ~exist('arg','var'), arg = []; end
    
    c0 = x(:,1);
    cf = c0 + x(:,3);
    r0 = x(:,2);
    rf = r0 + x(:,4);
    
    handle = draw_box( [c0 r0 cf rf], arg );
    
    if nargout > 0
        h = handle;
    end
    
end