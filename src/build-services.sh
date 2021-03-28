#!/bin/bash
export PREFIX=$( aws sts get-caller-identity | jq .Account -r ).dkr.ecr.eu-north-1.amazonaws.com

function build_and_push {
  for SERVICE in productpage details reviews ratings mysql mongodb
  do
    REPO_NAME="${PREFIX}/examples-bookinfo-${SERVICE}"
    echo ${REPO_NAME}
    docker image push  ${REPO_NAME} 
    echo "pushing ${REPO_NAME}"
  done
}

function build_images {

  if [ "$#" -ne 1 ]; then
      echo "Incorrect parameters"
      echo "Usage: build-services.sh <version>"
      return 1
  fi

  VERSION=$1
  SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

  pushd "$SCRIPTDIR/productpage"
    docker build --pull -t "${PREFIX}/examples-bookinfo-productpage:v1-${VERSION}" .
    #flooding
    docker build --pull -t "${PREFIX}/examples-bookinfo-productpage:v-flooding-${VERSION}" --build-arg flood_factor=100 .
    docker push "${PREFIX}/examples-bookinfo-productpage" --all-tags
  popd

  pushd "$SCRIPTDIR/details"
    #plain build -- no calling external book service to fetch topics
    docker build --pull -t "${PREFIX}/examples-bookinfo-details:v1-${VERSION}"  --build-arg service_version=v1 .
    #with calling external book service to fetch topic for the book
    docker build --pull -t "${PREFIX}/examples-bookinfo-details:v2-${VERSION}"  --build-arg service_version=v2 \
	   --build-arg enable_external_book_service=true .
  popd

  pushd "$SCRIPTDIR/reviews"
    #java build the app.
    docker run --rm -u root -v "$(pwd)":/home/gradle/project -w /home/gradle/project gradle:4.8.1 gradle clean build
    pushd reviews-wlpcfg
      #plain build -- no ratings
      docker build --pull -t "${PREFIX}/examples-bookinfo-reviews:v1-${VERSION}" --build-arg service_version=v1 .
      #with ratings black stars
      docker build --pull -t "${PREFIX}/examples-bookinfo-reviews:v2-${VERSION}" --build-arg service_version=v2 \
	     --build-arg enable_ratings=true .
      #with ratings red stars
      docker build --pull -t "${PREFIX}/examples-bookinfo-reviews:v3-${VERSION}" --build-arg service_version=v3 \
	     --build-arg enable_ratings=true --build-arg star_color=red .
    popd
  popd

  pushd "$SCRIPTDIR/ratings"
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v1-${VERSION}" --build-arg service_version=v1 .
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v2-${VERSION}" --build-arg service_version=v2 .
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v-faulty-${VERSION}" --build-arg service_version=v-faulty .
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v-delayed-${VERSION}" --build-arg service_version=v-delayed .
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v-unavailable-${VERSION}" --build-arg service_version=v-unavailable .
    docker build --pull -t "${PREFIX}/examples-bookinfo-ratings:v-unhealthy-${VERSION}" --build-arg service_version=v-unhealthy .
  popd

  pushd "$SCRIPTDIR/mysql"
    docker build --pull -t "${PREFIX}/examples-bookinfo-mysqldb:${VERSION}" -t "${PREFIX}/examples-bookinfo-mysqldb:latest" .
  popd

  pushd "$SCRIPTDIR/mongodb"
    docker build --pull -t "${PREFIX}/examples-bookinfo-mongodb:${VERSION}" -t "${PREFIX}/examples-bookinfo-mongodb:latest" .
  popd
}

function create_repo_ecr {
  for SERVICE in productpage details reviews ratings mysql mongodb
  do
    REPO_NAME="examples-bookinfo-${SERVICE}"
    echo ${REPO_NAME}
    aws ecr create-repository --repository-name ${REPO_NAME} 
  done
}

function delete_repo_ecr {
  for SERVICE in productpage details reviews ratings mysql mongodb
  do
    REPO_NAME="example-bookinfo-${SERVICE}"
    echo ${REPO_NAME}
    aws ecr delete-repository --repository-name ${REPO_NAME}
  done
}
