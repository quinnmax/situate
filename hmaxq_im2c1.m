
function [data,model] = hmaxq_im2c1( model, image )

    % [data,model] = hmaxq_im2c1( model, image );
    %
    % image can be an fname or an image matrix
    %
    % data.about has information about its contents
    % if no model was supplied, the output model will be what was used


    use_approximate_max = false;
    

    if ~exist('model','var') || isempty(model)
        model = hmaxq_model_initialize();
    end
    
    num_features = 3 + size(model.h1e,3);
    num_scales = length(model.scales);
    
    data = struct();
    data.about = { ...
        'im_r is the image resized';...
        's1 has s1 feature maps';...
        'c1a has receptive fields related to the size of the s1 filters';...
        'c1b has receptive fields related to the size of the c2 receptive fields';...
        'c1a_r resizes c1 maps to match up with each other, allowing for easy multiscale features';...
        'c1max takes the max value over an entire feature map, so is a num_scales x num_features matrix'};

    
    

    
    % load and store the image
    
        if ischar(image)
            % interpret as a file name, and try to open
            x = double( imread(image) ) / 255;
        elseif max(image(:)) > 1
            x = mat2gray(image);
        else
            x = image;
        end
        
        input_rows = size(x,1);
        input_cols = size(x,2);
        
        % data.im = x; % save off the original image. 
                          % we'll keep using x through the processing, so
                          % this can be commented out if we don't want the
                          % 'data' struct to bloat during larger
                          % experiments.
        
        % resize the image so approximate number of pixels is 'model.redim' (scale up or down)
        % if the model specification leaves this empty, this step is skipped
        if ~isempty(model.redim) && model.redim ~= 0
            x = imresize_px( x, model.redim );
        end
        
        data.im_r = x; % save off the resized input image as well.
        
        
        
        
        
        
        
        
        
        
        
        
    % split into color bands
        if size(x,3) == 3
            x = rgb2ycbcr(x);
        else
            x(:,:,2:3) = zeros(size(x,1),size(x,2),2);
        end 

        % im to s1 processing
        
        for si = 1:num_scales
            
            % we're looping through the scales specified in the model
            % x is scaled based on the scales list, allowing for processing
            % at different frequency bands. small scale values make the
            % image smaller, removing high frequency components.
            %
            % we do this rather than use gabors with lower frequency
            % sensitivities because the effective frequency sensitivities 
            % are equivalent, but the procesing required is much lower.

            cur_scale = model.scales(si);
            x_sc = imresize(x,cur_scale);
            
            % this is set up so that we apply processing to one layer, then
            % allocate the rest of the layers based on the output size of
            % the first. 
            %
            % note: consider center surround in addition to retinal?
            % or in place of? for the color opponency operation.
            %
            % color representation might need to be different depending on
            % the intended use. for an attentional application, contrast
            % between colors seems important (red/green), but 'phase' does
            % not (red/green vs green/red). for classification purposes,
            % the contrast seems less important than the absolute color
            % (red is important, rather than its relationship to green)
            
                s1        = retinal( x_sc(:,:,1), model.ret_w );                            % intensity
                s1(:,:,2) = retinal( x_sc(:,:,2), model.ret_w );                            % blue/yellow
                s1(:,:,3) = retinal( x_sc(:,:,3), model.ret_w );                            % red/green
                s1(:,:,end+1:end+size(model.h1e,3)) = filtern( model.h1e, x_sc(:,:,1) );    % edge orientation

                data.s1{si} = s1;
                
        end
        
        
        
%         % s1 to c1 processing
           
% 
%             % this doesn't bother storing the c1 stuff for each s1 scale
%             % separately. instead it process them each at their original
%             % scale, and then scales them up to be the same sized maps (in
%             % the size of the largest resulting c1 map)
%             %
%             % essentially, this destroys the pyramid.
%             % 
%             % whether this is appropriate or not: figure out later
% 
%             data.c1a_r = hmaxq_helper_s1c1( data.s1, model.c1a_w, model.c1a_w );
%             data.c1b_r = hmaxq_helper_s1c1( data.s1, model.c1b_w, model.c1b_s );

        
        for si = 1:num_scales
                
            % do one layer, then make room for the rest of c1 (a and b)
                
                s1 = data.s1{si};
                
                % intensity
                if use_approximate_max
                    c1a = local_extrema_approximate( s1(:,:,1), model.c1a_w );
                    c1a(:,:,2:num_features) = zeros( size(c1a,1), size(c1a,2), num_features-1 );
                    c1b = local_extrema_approximate( s1(:,:,1), model.c1b_w );
                    c1b(:,:,2:num_features) = zeros( size(c1b,1), size(c1b,2), num_features-1 );
                else
                    c1a = local_extrema( s1(:,:,1), model.c1a_w, model.c1a_s );
                    c1a(:,:,2:num_features) = zeros( size(c1a,1), size(c1a,2), num_features-1 );
                    c1b = local_extrema( s1(:,:,1), model.c1b_w, model.c1b_s );
                    c1b(:,:,2:num_features) = zeros( size(c1b,1), size(c1b,2), num_features-1 );
                end
                    
                    
                % color
                if use_approximate_max
                    for fi = 2:3
                        c1a(:,:,fi) = local_extrema_approximate( s1(:,:,fi), model.c1a_w );
                        c1b(:,:,fi) = local_extrema_approximate( s1(:,:,fi), model.c1b_w );                       
                    end
                else
                    for fi = 2:3
                        c1a(:,:,fi) = local_extrema( s1(:,:,fi), model.c1a_w, model.c1a_s );
                        c1b(:,:,fi) = local_extrema( s1(:,:,fi), model.c1b_w, model.c1b_s );                       
                    end
                end
                    
                % orientation
                if use_approximate_max
                    for fi = 4:num_features
                        c1a(:,:,fi) = local_max_approximate( abs(s1(:,:,fi)), model.c1a_w );
                        c1b(:,:,fi) = local_max_approximate( abs(s1(:,:,fi)), model.c1b_w );
                    end
                else
                    for fi = 4:num_features
                        c1a(:,:,fi) = local_max( abs(s1(:,:,fi)), model.c1a_w, model.c1a_s  );
                        c1b(:,:,fi) = local_max( abs(s1(:,:,fi)), model.c1b_w, model.c1b_s );
                    end
                end

            % store the computed outputs
                data.c1a{si} = c1a;
                data.c1b{si} = c1b;

        end

        
        
        % resize the c1a activations for easier S2 feature construction
            data.c1a_r = hmaxq_helper_c1a2c1a_r( data.c1a );
        
            
            
        % get per feature-map max values
        %   the distribution of this value, over multiple views of the same
        %   object, is the basis for the directed search model employed by
        %   Itti's group. 
        % Modifying this model with 
        %   a different color representation, 
        %   a different perspective on scale bands (extract more, look at only a band of adjacent), and 
        %   a few higher level configurational features
        %   seems to improve it substantially.
            data.c1max = squeeze( max( max( data.c1a_r ) ) );
            
        % compute per image salience, based on feature integration theory
        % of attention
            salience_stack = data.c1a_r;
            salience_stack = abs(salience_stack);
            
            for i = 1:size(data.c1a_r,3)
                salience_stack(:,:,i) = mat2gray(salience_stack(:,:,i)); 
                cur_layer_average_local_max = mean( reshape( salience_stack(:,:,i), 1, [] ) );
                cur_layer_global_max = 1; % which is the max of the layer, per mat2gray
                cur_layer_normalization_multiplier = ( cur_layer_global_max - cur_layer_average_local_max ) .^ 2;
                salience_stack(:,:,i) = cur_layer_normalization_multiplier * salience_stack(:,:,i);
            end
            
            data.salience = sum( salience_stack, 3 );
            data.salience_r = ...
                imresize( ...
                    data.salience, ...
                    [input_rows input_cols], ...
                    'nearest');

    
    
end







