
function [p, inhibited_result_image] = ior_peaks( x, n, inhibition_width, inhibition_type, inhibition_intensity )



    % [p, inhibited_result_image] = ior_peaks( x, n, inhibition_width, inhibition_type, inhibition_intensity );
    %
    % x is the empirical distribution from which we're fixating on
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
    % pulled). each row is a point, with the first entry being a row and
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
    

    
    demo_mode = false;
    if ~exist('x','var') || isempty(x)
        % x = disk(200,300);
        x = blackman(300) * blackman(300)';
        display('IOR_PEAKS IN DEMO MODE');
        demo_mode = true;
        x_original = x;
        n = 200;
    end

    if ~exist('n','var') || isempty(n)
        n = 1;
    end

    if n < 0
        error('ior_peaks:n must be non-negative');
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
        error('ior_peaks:inhibition_intensity_out_of_range');
    end


    
    
    floor_adjusted = false;
    min_x = min(x(:));
    if min_x < 0
        % if we have padding in there, this is creating a problem.
        % let's only do this scaling if there are values below zero
        x = x - min_x;
        floor_adjusted = true;
    end
    
    
    
    switch inhibition_type
        case 'blackman'
            h = 1 - inhibition_intensity * blackmann(inhibition_width);
        case 'disk'
            h = 1 - inhibition_intensity * disk(inhibition_width);
        otherwise
            error('ior_peaks:unrecognized inhibition type');
    end
    
    
    p = zeros(n,2);
    for ni = 1:n
        
        %[~,cc] = max( max( x ) );
        %[~,rc] = max(  x(:,cc) );
       
        [~,ind] = max( x(:) );
        rc = mod(ind-1,size(x,1))+1;
        cc = floor((ind-1)/size(x,1))+1;
        
        p(ni,:) = [rc cc];
        
        % find inhibition bounds
        r0 = rc - floor(inhibition_width/2);
        rf = r0 + inhibition_width - 1;
        c0 = cc - floor(inhibition_width/2);
        cf = c0 + inhibition_width - 1;

        % correct bounds if things have fallen off the edge
        h_r0 = 1;
        h_rf = size(h,1);
        h_c0 = 1;
        h_cf = size(h,2);
        if r0 < 1
            h_r0 = 1 + (1-r0);
            r0 = 1;
        end
        if c0 < 1
            h_c0 = 1 + (1-c0);
            c0 = 1;
        end
        if rf > size(x,1)
            h_rf = size(h,1) - (rf-size(x,1));
            rf = size(x,1);
        end
        if cf > size(x,2)
            h_cf = size(h,2) - (cf-size(x,2));
            cf = size(x,2);
        end
        
        x(r0:rf,c0:cf) = x(r0:rf,c0:cf) .* h(h_r0:h_rf,h_c0:h_cf);

    end
    
    
    
    if nargout > 1
        if floor_adjusted
            inhibited_result_image = x + min_x;
        else
            inhibited_result_image = x;
        end
    end
    
    
    
    % display the resulting points on the original distribution
    %   the first 10% of points drawn will be red
    if demo_mode
        figure;
        subplot(1,3,1); imshow(x_original); xlabel('input distribution');
        subplot(1,3,2); imshow(x_original); 
            hold on; 
            m = round(.1*n);
            plot(p(m+1:end,2),p(m+1:end,1),'b.','MarkerSize',20);
            plot(p(1:m,2),p(1:m,1),'r.','MarkerSize',20); 
            hold off; 
            xlabel([num2str(n) ' samples']);
        subplot(1,3,3); imshow(x,[]);
    end
    
   
end





























