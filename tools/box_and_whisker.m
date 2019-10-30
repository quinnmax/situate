function h = box_and_whisker( x, y, w, type )
% h = box_and_wisker( x, [2nd 25th 50th 75th 98th], w, 'spec' );
% h = box_and_wisker( x, data, w, 'data' );


    
    if nargin < 4
        if size(y,1) == 5
            type = 'spec';
        elseif size(y,1) > 5
            type = 'data';
        else
            error('less than 5 data points?');
        end
    end
    
    

    % if multiple cols, call recursively
    if numel(x) > 1 && numel(x) == size(y,2)
        
        if nargin < 3
            w = mean(diff(x))/2;
        end
        
        was_hold = ishold();
        h = cell(1,numel(x));
        for xi = 1:numel(x)
            h{xi} = box_and_whisker( x(xi), y(:,xi), w, type );
            hold on;
        end
        if ~was_hold, hold('off'); end
        return;
    end
       
  
    if nargin < 3
        w = .25;
    end

    
    
    

    if isequal( type, 'data')
        y = prctile( y, [2 25 50 75 98] );
    end

    was_hold = ishold();

    h = nan(1,6);
    
    % box
    h(1) = plot( [x-w/2 x+w/2 x+w/2 x-w/2 x-w/2], [y(2) y(2) y(4) y(4) y(2)], 'b');
    hold on;
    % median
    h(2) = plot( [x-w/2 x+w/2], [y(3) y(3)], 'r' );
    % wisker
    h(3) = plot( [x x], [y(4) y(5)], 'b');
    h(4) = plot( [x x], [y(1) y(2)], 'b');
    % caps
    h(5) = plot( [x-w/4 x+w/4], [y(1) y(1)], 'b');
    h(6) = plot( [x-w/4 x+w/4], [y(5) y(5)], 'b');

    if ~was_hold, hold('off'); end
    
end



   
        