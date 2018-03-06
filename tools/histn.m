

function histn( x, label, bins )

% histn( x, label, bins );
%
% generate separate histograms for the given labels, coloring them red and blue

    n = length(x);
    if ~exist('bins','var') || isempty(bins)
        bins = fix(sqrt(n));
    end

%     color = {'b','r'};
%     
%     [h0,c0] = hist( x(eq(0,label)), bins/length(unique(label)) );
%     [h1,c1] = hist( x(eq(1,label)), bins/length(unique(label)) );
%     
%     xmin = min([c0,c1]);
%     xmax = max([c0,c1]);
%     ymin = 0;
%     ymax = max([h0,h1]);
%     
%     width = (ymax - ymin) / (4*bins);
%     
%     hold on
%     bar(c0,h0,width,color{1})
%     bar(c1,h1,width,color{2})
%     hold off
%     
%     display(size(c0))
%     display(size(c1))
%     
%     
%     axis([ xmin xmax ymin ymax ]);
%     
    
    
    data1 = x(label);
    data2 = x(~label);
    hist(data1, bins);
    hold on; hist(data2, bins);
    c = get(gca, 'children');
    numfaces = size(get(c(1), 'Vertices'),1);
    set(c(1), 'FaceVertexCData', repmat([1 0 0], [numfaces 1]), 'Cdatamapping', 'direct', 'facealpha', 0.5, 'edgecolor', 'none');
    numfaces = size(get(c(2), 'Vertices'),1);
    set(c(2), 'FaceVertexCData', repmat([0 0 1], [numfaces 1]), 'Cdatamapping', 'direct', 'facealpha', 0.5, 'edgecolor', 'none');
    ylabel('Number of values');
    
end




