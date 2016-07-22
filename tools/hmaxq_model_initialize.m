


function model = hmaxq_model_initialize(verbose)
% model = hmaxq_model_initialize();

    
        if ~exist('verbose','var') || isempty(verbose)
            verbose = false;
        end

        
    
    % set layer 1 parameters

        model = struct();          
        
        % model.redim = [];
        model.redim = .1 * 10^6;   % rescale the input to roughly this many pixels
                                
        
        % model.scales = .5 .^ (-1:1:4);
        % model.scales = .5 .^ [-1 1 3];
        % model.scales = .5 .^ [0 1 2];
        model.scales = 2 .^ linspace(.5,-2,6); % [1.41, 1.00, 0.71, 0.50, 0.35, 0.25];
        
        
        model.ret_w = 15;     % size of window for retinal processing.
                              % I think integrating a center surround
                              % feature and a normalization step is more
                              % sound, as it would indicate a specific
                              % freqeuncy response that could be talked
                              % about. the current retinal method is a
                              % little harder to justify, but also isn't
                              % used for much other than blob detection and
                              % color opponency.

        model.s1_w = 9;                          % size of S1 filters
        model.s1_r = 4;                          % number of S1 rotations (for Gabors)
            % these parameters produce a nice looking FFT, with pretty even
            % coverage with respect to orientations, and no aliasing
            % artifacts.
            % they're most sensitive to the .5 frequency (that is, half of
            % the highest possible frequency in the image), so to get
            % access to the highest frequency, use these gabors, but double
            % the size of the image.
            % there's a V1_filters_ts that can give a good look at the
            % frequency responses that come out of gabors with these
            % parameters.
        model.c1a_w   = model.s1_w;                 % C1 pooling width
        model.c1a_s   = round(model.c1a_w/sqrt(2)); % C1 pooling step size (sqrt(2) is full coverage with minimal overlap
        model.s1_rule = 'gabors';                   % { 'ica', 'kmeans', 'gabors' }
            % support for the other S1 rules has been removed. It's
            % interesting, but in general, we should just be using gabors.
            % I think it's interesting to talk about the learning rules and
            % what they do at the low-level, as justification for their
            % usefulness before applying them to mid-level learning, but I
            % don't really think that's worth actually using.

            
    
    % build layer 1 gabors

        n = model.s1_w;
        n = n*4;
        x = sin(linspace(-2*pi,2*pi,n))';
        h_ed_base = (x * ones(1,n)) .* (blackman(n) * blackman(n)');

        nr = model.s1_r;
        rotations = linspace(0,180,nr+1);
        rotations(end) = [];

        for ri = 1:length(rotations)
            h_ed_temp = imrotate(h_ed_base,rotations(ri),'bilinear','crop');
            h_ed(:,:,ri) = imresize(h_ed_temp,1/4);
        end
        model.h1e = h_ed;

        if verbose
            figure('Name','Gabor frequency response'); 
            imshow(sum(fftshift(abs(fft2(model.h1e,100,100))),3),[]);
        end
        
        
    % build layer 1 center surround
    
        % this center surround is built to have a similar frequency
        % response to the 9 unit Gabors, and uses an error function to get
        % as close as possible to an unbiased filter
        % I'm using Blackman windows instead of Gaussians for the windowing
        % function (both here and for the Gabors), which is very similar to 
        % 3 sigmas out with a Gaussian, but actually goes to zero at the 
        % ends.
        %
        % to compare:
        %   y_blackman = blackman(100);
        %   y_gaussian = normpdf(linspace(-3,3,100));
        %   y_gaussian = y_gaussian/max(y_gaussian);
        %   figure;
        %   hold on;
        %   plot(y_gaussian,'r');
        %   plot(y_blackman,'b');
        %   hold off;
        
        n = 12;

        t = linspace(-1,1,n);
        [x,y] = meshgrid(t,t);          
        d = sqrt( x.^2 + y.^2 );        % distance to center
        x = cos( 2*pi * d );            % radial cosine
        e = blackman(n) * blackman(n)'; % Blackman envelope

        % vary the cosine/envelope offset to get an unbiased response
        error = @(a) mean(reshape((x+a).*e,1,[])).^2; 
        a = fminsearch(error,0);
        h_cc = (x+a) .* e;
        
        model.h1cc = h_cc;
        
        if verbose
            figure('Name','Center Surround frequency response'); 
            imshow(sum(fftshift(abs(fft2(model.h1cc,100,100))),3),[]);
        end

    % num c1 features
       model.calc_num_c1_features = @(not_used)(size(model.h1e,3) + 3) * length(model.scales);
       model.num_c1_features = model.calc_num_c1_features(model);
       
    
    % set layer 2 parameters    

        model.s2_n    = 12;                         % number of features for S2
        model.s2_w    = 11;                         % size of S2 filters
        model.c2_w    = model.s2_w;                 % C2 pooling width
        model.c2_s    = round(model.c2_w/sqrt(2));  % C2 pooling step size
        model.s2_rule = 'kmeans';                   % { 'ica', 'kmeans' } % later, simple shapes

        model.c1b_w = (model.c2_w - 1) * model.c1a_s + model.c1a_w;
        model.c1b_s = fix( model.c1b_w / 2 );



end


