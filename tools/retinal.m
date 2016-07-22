function [y,x_mu,x_sigma] = retinal( x, rp, cutoff )
    % [y,x_mu,x_sigma] = retinal( x, rp, [cutoff] );
    % Turns the intensity image into a contrast image.
    % Should roughly approximate a standard normal in "active regions".
    % rp is the region around a cell that mean and std are calculated over.
    %
    % [retinal_output] = retinal( mat2gray(imread('cameraman.tif')), 15 );
    % figure; subplot(1,2,1); imshow(mat2gray(imread('cameraman.tif')));
    %         subplot(1,2,2); imshow(retinal_output + .5);
    
        if ~exist('rp','var') || isempty(rp)
            rp = 15;
        end
        
        if ~exist('cutoff','var') || isempty(cutoff)
            cutoff = .1;
        end

        % local mean and standard deviation
            h = disk(rp);
            h = h / sum(h(:));
            
            x_mu  = filtern( h, x );
            x2_mu = filtern( h, x.^2 );
            x_sigma = sqrt( max( 0, x2_mu - x_mu.^2 ) );
            % x2_mu should always be larger, 
            % but if they're close, it can round the wrong way, 
            % so i included a max(0,...) to make sure it doesn't bonk

        % approximate locally standard normal, maybe with noise cutoff
            y = (x - x_mu) ./ max(x_sigma, cutoff);
            % y = (x - x_mu) ./ (x_sigma + 1 - blackman_cdf( x_sigma, 0, cutoff)); 

        % bring roughly to (-1,1)
            y = y / 3;
   
            
            
end
