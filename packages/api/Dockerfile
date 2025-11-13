# Use AWS Lambda Python 3.11 base image
FROM public.ecr.aws/lambda/python:3.11

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies for PostgreSQL and other requirements
RUN yum install -y \
        postgresql \
        gcc \
        python3-devel \
        postgresql-devel \
        curl \
    && yum clean all

# Copy requirements and install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy API project
COPY . ${LAMBDA_TASK_ROOT}/

# Create directory for static files
RUN mkdir -p ${LAMBDA_TASK_ROOT}/staticfiles

# Set the CMD to your handler
CMD [ "lambda_handler.lambda_handler" ]
