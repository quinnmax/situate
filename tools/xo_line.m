function h = xo_line( x, y, arg )

% h = xo_line( x, y, arg );
%
% x(1),y(1) starting point, x
% x(2),y(2) ending point,   o
% arg should just be color (r,b,k,g,etc)
% 
% h is handle for [x, line, o];

    h = zeros(1,3);
    hold_was_on = ishold();
    hold on
    h(1) = plot(x(1),y(1),['x' arg]);
    h(2) = plot(x,y,['-' arg]);
    h(3) = plot(x(2),y(2),['o' arg]);
    if ~hold_was_on
        hold off;
    end