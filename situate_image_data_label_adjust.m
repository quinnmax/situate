function image_data_out = situate_image_data_label_adjust( image_data_in, p )



<<<<<<< 0de97f7a360c61505ffc8d68993658e91e859092
<<<<<<< 36041c5590a8ddbc23649424c1dacbd85ed4a85e
% label_out = situate_image_data_label_adjust( image_data_in, p );
=======
%  label_out = situate_image_data_label_adjust( image_data_in, p );
>>>>>>> just working on making the mvn conditioning and sampling a little more efficient. it's the bottleneck right now
=======
% label_out = situate_image_data_label_adjust( image_data_in, p );
>>>>>>> I rearranged some spaces or something
%
%   add labels_adjusted to the situate_image_data_struct
%   using the mapping from p.situation_objects_possible_labels to
%   p.situation_objects.
%
% If there are multiple final labels to which a raw label can be assigned,
% then there's a global iteration that changes which it is assigned to.
% This means if there are two final labels {player1, player2}, and they
% both accept the same set of raw labels {player front, player back, etc},
% then the first raw_label will go to player1, and the next to player2,
% then back to player1.

global assignment_counter
if isempty(assignment_counter), assignment_counter = 0; end

    if isstruct(image_data_in) && length(image_data_in) > 1 
    % we're looking at a struct array, so we need to go through and make new ones
        
        image_data_out = situate_image_data_label_adjust( image_data_in(1), p );
        image_data_out = repmat( image_data_out, 1, length(image_data_in) );
        for i = 2:length(image_data_in)
            image_data_out(i) = situate_image_data_label_adjust( image_data_in(i), p );
        end
        
    elseif iscellstr(image_data_in)
        % we just have file names, so get the image data first, and then do the
        % adjustment
        fnames_in = image_data_in;
        image_data_temp = situate_image_data(fnames_in);
        image_data_out = situate_image_data_label_adjust( image_data_temp, p );

    else
    % we've got a singular struct, so just make the adjustment and return it
        
        image_data_out = image_data_in;
        image_data_out.labels_adjusted = cell(size(image_data_in.labels_raw));
        for i = 1:length(image_data_in.labels_raw)
            cur_label_raw = image_data_in.labels_raw{i};
            possible_label_inds = [];
            for j = 1:length(p.situation_objects_possible_labels)
                if ismember( cur_label_raw, p.situation_objects_possible_labels{j})
                    possible_label_inds = [possible_label_inds j];
                end
            end
            
            switch length(possible_label_inds)
                case 0, 
                    image_data_out.labels_adjusted{i} = 'unknown_object';
                case 1, 
                    image_data_out.labels_adjusted{i} = p.situation_objects{possible_label_inds};
                otherwise
                    if assignment_counter == 0
                        image_data_out.labels_adjusted{i} = p.situation_objects{possible_label_inds(1)};
                    else
                        image_data_out.labels_adjusted{i} = p.situation_objects{possible_label_inds(2)};
                    end
                    assignment_counter = mod(assignment_counter + 1, length(possible_label_inds) );
            end
            
        end
    
    end
    
    
    
end
   