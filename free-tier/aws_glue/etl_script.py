import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'output_path'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from Glue catalog
datasource0 = glueContext.create_dynamic_frame.from_catalog(
    database="learning_glue_db",
    table_name="employees",
    transformation_ctx="datasource0"
)

# Write to S3 in Parquet format
datasink1 = glueContext.write_dynamic_frame.from_options(
    frame=datasource0,
    connection_type="s3",
    connection_options={"path": args['output_path']},
    format="parquet",
    transformation_ctx="datasink1"
)

job.commit()