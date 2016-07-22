function h = plot_onto_imshow( x,y,x_vals,y_vals,format_string)

% h = plot_onto_imshow( x,y,x_vals,y_vals,format_string);
%
% for an imshow that has associated x and y values for the matrix entries,
% this will make it easier to plot onto the image.
%
% for example, if the image shows z values for an x range of [-1 1] and a y
% range of [-2 0], and you want to plot a point at the origin, then call
%
% imshow( image );
% hold on;
% x_vals = linspace(-1,1,size(image,2);
% y_vals = linspace(-2,0,size(image,1);
% h = plot_onto_imshow( 0, 0, x_vals, y_vals );

    if length(x) ~= length(y)
        error('x,y lengths must match');
    end
    
    rs = zeros(length(x),1);
    cs = zeros(length(y),1);
    
    for i = 1:length(x)
        [~,cs(i)] = min(abs( x(i) - x_vals ));
        [~,rs(i)] = min(abs( y(i) - y_vals ));
    end
    
    if ~exist('format_string','var')
        h = plot(cs,rs);
    else
        h = plot(cs,rs,format_string);
    end
    
    
    
end
        
        