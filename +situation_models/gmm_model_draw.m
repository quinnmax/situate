function h = gmm_model_draw( d, object_string, viz_spec, samples_respresented, samples_represented_formatting, is_initial_draw  )
% h = gmm_model_draw( d, object_string, viz_spec, input_agent_or_box, is_initial_draw );
%
%   what to draw can be 'xy', 'shape', or 'size'
%       xy will be a heat map the shape of the image
%       shape will be a single dimensional distribution of log aspect ratio
%       size  will be a single dimensional distribution of log area ratio
%   each is marginalized from the full sized distribution
%
%   if input_agent and/or box_r0rfc0cf are include,
%   a representation of the sample (as a point or box) indicating the location or desnity 
%   of that sample will be included in the figure





    if ~isempty(samples_respresented) 
        %box_r0rfc0cf = input_agent.box.r0rfc0cf;
        box_r0rfc0cf = samples_respresented;
    end

    if ~exist('is_initial_draw','var') || isempty(is_initial_draw)
        is_initial_draw = false;
    end

    i = find(strcmp( {d.interest}, object_string ));
    
    im_r = d(i).image_size(1);
    im_c = d(i).image_size(2);

    h = [];

    % figure out offset for objects in distribution
    if ~d(i).distribution.is_conditional
        params_per_obj = length( d(i).distribution.parameters_description );
        block_ind_0 = params_per_obj * ( find( strcmp( object_string, d(i).distribution.situation_objects)) - 1 );
    else
        block_ind_0 = 0;
    end

    persistent prev_distribution_struct; % stores a copy of the most recently draw dist struct, for comparison
    persistent up_to_date_fig_inds; % an array that lets us know which obj visualizations are up-to-date

    
    switch viz_spec

        case 'xy'

            % visualize the distribution of box centers
            
            if ~is_initial_draw && ~isempty(prev_distribution_struct) && isequal(d,prev_distribution_struct) && ismember( i, up_to_date_fig_inds )
                % no need to redraw
                % the majority of calls fall into this category
            else
  
                % marginalize for the x and y positions
                rc_ind = strcmp( d(i).distribution.parameters_description, 'rc' ); % row-center ind
                cc_ind = strcmp( d(i).distribution.parameters_description, 'cc' ); % column-center ind
                inds_want = block_ind_0 + find(any([ rc_ind; cc_ind ]));
                inds_have = [];
                data_have = [];
                model_marginalized = gmm_condition( d(i).distribution, inds_want, inds_have, data_have );
                
                % generate the map
                lsf = sqrt( 1 / (im_r * im_c ) ); % linear scaling factor
                x_vals = linspace( im_c * lsf * -.5, im_c * lsf * .5, im_c );
                y_vals = linspace( im_r * lsf * -.5, im_r * lsf * .5, im_r );
                [X, Y] = meshgrid( x_vals, y_vals );
                Z_flat = gmmpdf( [Y(:) X(:)], model_marginalized );
                Z = reshape( Z_flat,im_r, im_c );
                
                % draw
                imshow(Z,[]);
                
                % save to prevent redrawing
                if ~isequal(prev_distribution_struct,d)
                    prev_distribution_struct = d;
                    up_to_date_fig_inds   = [];
                end
                up_to_date_fig_inds = unique([up_to_date_fig_inds i]);

            end

            % draw the specified agent
            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)
                % if we're drawing a workspace box and an agent
                % box, and they're the same, we should just draw
                % one of them. The first one is the workspace box,
                % so we'll do that.
                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('samples_represented_formatting','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'b'; end

                h = zeros(1,boxes_to_draw);
                for bi = 1:boxes_to_draw
                    hold on; 
                    if iscell(samples_represented_formatting)
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', samples_represented_formatting{bi} );
                    else
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', samples_represented_formatting );
                    end
                    hold off
                end
            end

        case 'shape'

            % marginalize for the feature we want
            aspect_ind = strcmp( d(i).distribution.parameters_description, 'log aspect ratio' );
            inds_want  = block_ind_0 + find(aspect_ind);
            inds_have = [];
            data_have = [];
            model_marginalized = gmm_condition( d(i).distribution, inds_want, inds_have, data_have );
            k = length(model_marginalized.pi);
            
            % figure out the domain to display
            cur_x_min = inf;
            cur_x_max = -inf;
            for ki = 1:k
                cur_x_min = min( cur_x_min, model_marginalized.mu(ki) - 3*sqrt(model_marginalized.Sigma(1,1,ki)) );
                cur_x_max = max( cur_x_max, model_marginalized.mu(ki) + 3*sqrt(model_marginalized.Sigma(1,1,ki)) );
            end
            x_vals = linspace(cur_x_min,cur_x_max,100);
            y_vals = gmmpdf( x_vals, model_marginalized );
            plot( x_vals, y_vals, '-b' );
            
            % add tic marks and labels
            xlim([-2,2]);
            h_temp = gca;
            h_temp.XTick      = [ log(.25)  log(.5) log(1) log(2) log(4) ];
            h_temp.XTickLabel = { '1:4' '1:2' '1:1' '2:1' '4:1'};
            xlabel('shape (W:H)');

            % draw the specified agent
            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)
                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('samples_represented_formatting','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'ob'; end
                for bi = 1:boxes_to_draw
                    r0 = box_r0rfc0cf(bi,1);
                    rf = box_r0rfc0cf(bi,2);
                    c0 = box_r0rfc0cf(bi,3);
                    cf = box_r0rfc0cf(bi,4);
                    width  = cf - c0 + 1; 
                    height  = rf - r0 + 1;
                    x_val = log(width/height);
                    y_val = gmmpdf( x_val, model_marginalized );
                    hold on;
                    if iscell(samples_represented_formatting)
                        plot( x_val, y_val, ['o' samples_represented_formatting{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' samples_represented_formatting(end)]);
                    end
                    hold off
                end
            end

        case 'size'

            % marginalize for the feature we want
            area_ind = strcmp( d(i).distribution.parameters_description, 'log area ratio' );
            inds_want = block_ind_0 + find(area_ind);
            inds_have = [];
            data_have = [];
            model_marginalized = gmm_condition( d(i).distribution, inds_want, inds_have, data_have );
            k = length(model_marginalized.pi);
            
            % figure out the domain to display
            cur_x_min =  inf;
            cur_x_max = -inf;
            for ki = 1:k
                cur_x_min = min( cur_x_min, model_marginalized.mu(ki) - 3*sqrt(model_marginalized.Sigma(1,1,ki)) );
                cur_x_max = max( cur_x_max, model_marginalized.mu(ki) + 3*sqrt(model_marginalized.Sigma(1,1,ki)) );
            end
            x_vals = linspace(cur_x_min,cur_x_max,100);
            y_vals = gmmpdf( x_vals, model_marginalized );
            plot( x_vals, y_vals, '-b' );
            
            % add tic marks and labels
            xlim([-7,0.5]);
            h_temp = gca;
            h_temp.XTick = [ log(.001) log(.01) log(.1)   log(.5) log(1) ];
            h_temp.XTickLabel = {'.001' '.01' '.1'   '.5' '1'};
            xlabel('area (box/image)');

            % draw the specified agent
            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)
                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('box_format_arg','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'ob'; end
                for bi = 1:boxes_to_draw
                    r0 = box_r0rfc0cf(bi,1);
                    rf = box_r0rfc0cf(bi,2);
                    c0 = box_r0rfc0cf(bi,3);
                    cf = box_r0rfc0cf(bi,4);
                    width  = cf - c0 + 1; 
                    height  = rf - r0 + 1;
                    x_val = log( (width*height) / (im_r*im_c) );
                    y_val = gmmpdf( x_val, model_marginalized);
                    hold on;
                    assert( y_val > 0 );
                    if iscell(samples_represented_formatting)
                        plot( x_val, y_val, ['o' samples_represented_formatting{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' samples_represented_formatting(end)]);
                    end
                    hold off
                end
            end

        otherwise
            warning(['unrecognized viz spec: ' viz_spec]);
            
    end
        
end

                    
                    
               
        
        


        
        
