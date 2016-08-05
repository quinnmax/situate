


function [inds,p,point_density] = sample_2d(pdf,n,x,y)



    % [inds,p] = sample_2d( pdf, n, [x_vals], [y_vals] );
    %
    % draw samples from a 2d empirical (discretized) pdf
    %
    % inds has the indices of the sampled locations
    %   column 1 of inds is the row of pdf
    %   column 2 of inds is the column of pdf
    %
    % p has the coordinate values, if you provided that info in [x,y]
    %   column 1 of p is the x value sampled
    %   column 2 of p is the y value sampled
    %
    % notice that the ording here is essentially switched from the version
    % that does not provide [x,y] values. this is to respect the usual
    % [row,column] ordering for matrix indexing, 
    % and [x,y] ordering for coordinates
    %
    % if x and y are provided, they should be the values associated with
    % columns and rows of the pdf (respectively). if they are not provided,
    % then p will be the same as ind (although the columns are swapped)
    %
    % see also:
    %   sample_1d

    
    
    demo_mode = false;

    if ~exist('pdf','var') || isempty(pdf)
        pdf = imread('lincoln.jpg');
        pdf = rgb2gray(pdf);
        pdf = double(pdf)/255;
        pdf = mat2gray(pdf).^4;
        demo_mode = true;
        
        %pdf = zeros(100,100);
        %pdf(41,21) = 1;
        
    end

    if ~exist('n','var') || isempty(n)
        n = 5000;
        demo_mode = true;
    end
    
    if ~exist('x','var') || isempty(x)
        x = 1:size(pdf,2);
    end
    
    if ~exist('y','var') || isempty(y)
        y = 1:size(pdf,1);
    end

    
    persistent pdf_persistent
    persistent cumsum_pdf
    persistent sum_pdf
    if ~isequal(pdf_persistent, pdf)
        cumsum_pdf = cumsum(pdf(:));
        sum_pdf = sum(pdf(:));
        pdf_persistent = pdf;
        epsilon = .00000001;
        if sum_pdf-1 < 0 || sum_pdf-1 > epsilon
            cumsum_pdf = cumsum_pdf/sum_pdf;
        end
    end
    
    r = rand(1,n);
    s = zeros(1,n);

    for ni = 1:n
        s(ni) = find( cumsum_pdf > r(ni), 1, 'first' );
    end

    rows = size(pdf,1);
    inds = zeros(n,2);
    inds(:,1) = mod(s-1,rows)+1;
    inds(:,2) = floor((s-1)/rows)+1;

    p = zeros(size(inds));
    p(:,1) = x( inds(:,2) );
    p(:,2) = y( inds(:,1) );
    
    point_density = s./sum_pdf;
    
    if demo_mode
        display('sample_2d is in DEMO MODE');
        figure;
        imshow(pdf);
        hold on;
        plot(inds(:,2),inds(:,1),'.');
        hold off;
    end
    
    
    
end






