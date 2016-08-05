
function [p, inhibited_result_image, point_density] = ior_sampling( x, n, inhibition_width, inhibition_type, inhibition_intensity )



    % [p, inhibited_result_image] = ior_sampling( x, n, inhibition_width, inhibition_type, inhibition_intensity );
    %
    % x is the empirical distribution from which we're sampling
    % n is the number of samples to pull (time is linear in n)
    % inhibition_width defines how large an area around a sampled location
    %   should be inhibited
    % inhibition_type determines the shape of the inhibition region.
    %   'blackman' uses a blackman envelope (gaussian like)
    %       the width will specify something close to 6 standard deviations 
    %       of a normal distribution
    %   'disk' uses a solid disk
    % inhibition_intensity specifies how strong the inhibition is at the
    %   sampled location. 1 is the default, and is full inhibition.
    %
    % p is an array of the resuling points (in the order that they were
    % sampled). each row is a point, with the first entry being a row and
    % the second a column.
    %
    % inhibited_result_image is just the result of the input after having
    % had regions inhibited, just to get a sense of what's left if that's
    % helpful. certainly not needed in general.
    %
    % if run without an input distribution x, the function will run in demo
    % mode with a 300x300 image with a 200 pixel disk in the center. 
    %
    % see also:
    %   empdist_sampling
    %   ior_sampling_ts
    %   ior_sampling
    %
    
    

    
    demo_mode = false;
    if ~exist('x','var') || isempty(x)
        error('ior_sampling: no input image');
    end

    if ~exist('n','var') || isempty(n)
        error('number of samples not specified');
    end

    if ~exist('inhibition_width','var') || isempty(inhibition_width)
        inhibition_width = round(max(size(x))/10);
    end

    if ~exist('inhibition_type','var') || isempty(inhibition_type)
        inhibition_type = 'blackman';
    end
    
    if ~exist('inhibition_intensity','var') || isempty(inhibition_intensity)
        inhibition_intensity = 1;
    end

    if inhibition_intensity < 0 || inhibition_intensity > 1
        error('ior_sampling:inhibition_intensity_out_of_range');
    end
    
    
    point_density = zeros(0,n);
    
    
    min_x = min(x(:));
    max_x = max(x(:));
    if min_x < 0
        if min_x ~= max_x
        % if we have padding in there, this is creating a problem.
        % let's only do this scaling if there are values below zero
            x = (x - min_x) / (max_x - min_x);
        end
    end
    
    
    
    padding_width = inhibition_width;
    %xp = padarray( x, [padding_width,padding_width], 0 );
    xp = zeros(size(x,1)+2*padding_width,size(x,2)+2*padding_width,size(x,3));
    xp(padding_width+1:end-padding_width,padding_width+1:end-padding_width,:) = x;

    switch inhibition_type
        case 'blackman'
            h = 1 - inhibition_intensity * blackmann(inhibition_width);
        case 'disk'
            h = 1 - inhibition_intensity * disk(inhibition_width);
        otherwise
            error('ior_sampling:unrecognizedInhibitionType',['ior_sampling:unrecognizedInhibitionType \n inhibition_type was ' inhibition_type ]);
    end
    
    p = zeros(n,2);
    for ni = 1:n

        % pick a point
        total = sum(xp(:));
        if total ~= 0
            cs = cumsum( xp(:) ) / total;
            r = rand();
            s = find( gt( cs, r ), 1, 'first' );
        else
            % treat it as uniform non-zero
            s = randi(length(xp(:)));
        end
        rows = size(xp,1);
        rc = mod(s-1,rows)+1;
        cc = floor((s-1)/rows) + 1;
        
        % find inhibition bounds
        r0 = rc - floor(inhibition_width/2);
        rf = r0 + inhibition_width - 1;
        c0 = cc - floor(inhibition_width/2);
        cf = c0 + inhibition_width - 1;

        % make sure the point is in the original image bounds 
        % ( this should always be true, but am a little paranoid )
        is_good_point = ...
            ~isempty(rc) && ...
            ~isempty(cc) && ...
            rc >= padding_width + 1 && ...
            cc >= padding_width + 1 && ...
            rc <= size(x,1) + padding_width && ...
            cc <= size(x,2) + padding_width;

        if  is_good_point
            p(ni,:) = [rc,cc];
            point_density(ni) = xp(rc,cc)/sum(xp(:));
            % inhibit
            xp(r0:rf,c0:cf) = xp(r0:rf,c0:cf) .* h;
        else
            warning('ior_sampling:bad point was picked...');
        end

    end

    % unpad the points so they fit onto the original x properly
    
    p = p - padding_width;
    
    % display the resulting points on the original distribution
    %   the first 5% of points drawn will be red
    
    if demo_mode
        figure;
        subplot(1,3,1); imshow(x); xlabel('input distribution');
        subplot(1,3,2); imshow(x); 
            hold on; 
            m = round(.05*n);
            plot(p(m+1:end,2),p(m+1:end,1),'b.');
            plot(p(1:m,2),p(1:m,1),'r.'); 
            hold off; 
            xlabel([num2str(n) ' samples']);
        subplot(1,3,3); imshow(xp,[]); xlabel('residual');
    end
    
    if nargout > 1
        inhibited_result_image = unpadarray(xp,[padding_width,padding_width]);
    end
    
end





























