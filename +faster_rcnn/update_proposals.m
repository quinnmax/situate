function boxes = update_proposals( boxes, mu, sigma )
%UPDATE_PROPOSALS Updates and sorts the box proposals according to a MVN

   scores = mvnpdf(boxes(:, 1:4), mu, sigma);
   boxes = [boxes(:, 1:4), boxes(:, 5) * scores];
   boxes = sortrows(boxes, -5);

end

