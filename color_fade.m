
function output = color_fade(colors, n )

    % output = color_fade( n );
    % output = color_fade(colors, n );
    %
    % with one arg, colors will be magenta to green

    
    if nargin < 2
        n = colors;
        colors = [];
        colors(1,:) = [1 0 1];
        colors(3,:) = [0 0 0];
        colors(4,:) = [0 1 0];
    end
    
    
    ns = round(linspace(1,n,size(colors,1)));
    
    
    
    output = [];
    for ci = 1:(size(colors,1)-1)
        
        cur_steps = ns(ci+1)-ns(ci) + 1;
        color_temp = [ ...
            linspace(colors(ci,1),colors(ci+1,1),cur_steps)', ...
            linspace(colors(ci,2),colors(ci+1,2),cur_steps)', ...
            linspace(colors(ci,3),colors(ci+1,3),cur_steps)'  ];
        output = [output; color_temp(1:end-1,:)];
        
    end 
    output = [output; colors(end,:)];
end






