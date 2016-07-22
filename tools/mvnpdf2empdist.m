function [map, xvals, yvals] = mvnpdf2empdist( mu, Sigma, rows, cols )

    % [map, xvals, yvals] = mvnpdf2empdist( mu, Sigma, rows, cols );

    demo_mode = false;
    if ~exist('mu','var') || isempty(mu)
        mu = [0 2];
        Sigma = [1 0; 0 2];
        rows = 200;
        cols = 200;
        demo_mode = true;
        warning('mvnpdf2empdist in demo mode');
    end
    
    x0 = mu(1) - 3 * sqrt(Sigma(1,1));
    xf = mu(1) + 3 * sqrt(Sigma(1,1));
    
    y0 = mu(2) - 3 * sqrt(Sigma(2,2));
    yf = mu(2) + 3 * sqrt(Sigma(2,2));
    
    xvals = linspace(x0,xf,cols);
    yvals = linspace(y0,yf,rows);
    
    [X,Y] = meshgrid(xvals, yvals);
    
    Z = mvnpdf([X(:) Y(:)], mu, Sigma );
    
    map = reshape(Z,size(X));
    
    if demo_mode
        
        h = figure();
        set(h, 'Position', [0, 500, 1100, 700]);
        
        for box_dist_ind = 1:3
            subplot2(3,6,2,3+box_dist_ind,3,3+box_dist_ind); 
            f = imshow(map,[]);
            title({'two line','title'});
            
            xlabel('test x');
            f.Parent.Visible = 'on';
            f.Parent.XTick = [1 100 200];
            f.Parent.XTickLabel = {'a','b','c'};
            
            ylabel('test y with a really long text');
            f.Parent.Visible = 'on';
            f.Parent.YTick = [1 100 200];
            f.Parent.YTickLabel = {'d','e','f'};
            
        end
      
    end
    
end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    