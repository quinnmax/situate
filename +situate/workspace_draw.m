

function h = workspace_draw( input, p, workspace, font_size )

    % handle_array = situate.workspace_draw( input, p, workspace )
    %
    %   h is the handle to the output figure, specifically the image
    %   input can be an image fname, an image matrix, 
    %       or a handle to an exisiting image
    %       if empty, just draws into current axes
    %   p is a situate parameters structure
    %   workspace is the situate workspace to draw
   
    bounding_box_format_provisional = {'r--',  'LineWidth', 2 };
    bounding_box_format_final = {'r','LineWidth', 2} ;
     
    h = [];
    
    if ~exist('font_size','var')
        font_size = 8;
    end
    
    %% figure out what the input was 
    %   might be an image fname, an image matrix, or a handle to an existing figure
    %   if empty, then just draws into current axes without trying to switch anything around
        
        if ~isempty(input)
            switch class(input)
                case 'char'
                    try
                        x = imread(input);
                    catch
                        warning(['image not found: ' input]);
                        x = .25 * ones( workspace.im_size(1), workspace.im_size(2), 3);
                    end
                    h(1) = imshow( x, [] );
                case {'double', 'uint8'}
                    if all(ishandle(input))
                        axes(input);
                    else
                        x = input;
                        h(1) = imshow( x, [] );
                    end
                case 'matlab.graphics.axis.Axes'
                    axes(input);
                case 'matlab.ui.Figure'
                    axes(input.CurrentAxes);
                otherwise
                    error('situate.workspace_draw doesn''t recognize the input provided');
            end
        end

        
        
    %% draw workspace boxes onto main image
    
        if ~exist('p','var') || isempty(p) || ~isfield(p,'thresholds')
            total_support_threshold_final = .5;
        else
            total_support_threshold_final = p.thresholds.total_support_final;
        end
    
        hold on;
        for wi = 1:size(workspace.boxes_r0rfc0cf,1)
            if workspace.total_support(wi) >= total_support_threshold_final
                % was UserData.handles(end+1) = 
                h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_final{:});
            else
                % was UserData.handles(end+1) = 
                h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_provisional{:});
            end
        end

        
        
    %% then draw the text ( so boxes don't cover text )
    
        for wi = 1:size(workspace.boxes_r0rfc0cf,1)
            
            label_text = workspace.labels{wi};
            
            x_position = workspace.boxes_r0rfc0cf(wi,3);
            y_position = workspace.boxes_r0rfc0cf(wi,1);
            
            t1 = text( x_position, y_position, label_text);
            set(t1,'color',[eps 0 0]);
            set(t1,'FontSize',font_size);
            set(t1,'FontWeight','bold');
            t2 = text( x_position+1, y_position+1, label_text);
            set(t2,'color',[1-eps 1 1]);
            set(t2,'FontSize',font_size);
            set(t2,'FontWeight','bold');
            
            h(end+1) = t1;
            h(end+1) = t2;
            
            detailed_text = {...
                workspace.labels{wi}; ...
                ['  int: ' sprintf('%0.4f', workspace.internal_support(wi) ) ]; ...
                ['  ext: ' sprintf('%0.4f', workspace.external_support(wi) ) ]; ...
                ['  tot: ' sprintf('%0.4f', workspace.total_support(wi)    ) ]; ...
                ['  gt : ' sprintf('%0.4f', workspace.GT_IOU(wi)           ) ]};
            
            x_position = workspace.im_size(2)+10;
            
            if ~exist('p','var') || isempty(p) || ~isfield(p,'situation_objects')
                num_objs = length(workspace.labels);
            else
                num_objs = length(p.situation_objects);
            end
            
            y_positions = linspace( 1, workspace.im_size(1), 2 * num_objs+1 );
            y_positions = y_positions(2:2:end-1);
            
            
            if exist('p','var') && ~isempty(p) && isfield(p,'situation_objects')
                y_position = y_positions(strcmp(workspace.labels{wi},p.situation_objects));
            else
                y_position = y_positions(wi);
            end
            
            t3 = text( x_position, y_position, detailed_text);
            set(t3,'color',[eps 0 0]);
            set(t3,'FontSize',font_size);
            set(t3,'FontWeight','bold');
            
            h(end+1) = t3;
            
        end
        hold off;

        
        
end
